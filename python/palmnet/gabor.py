"""Fixed and adaptive Gabor banks from the uploaded MATLAB implementation."""
import logging
import math
import numpy as np
import torch
from .ops import myconv2, ridge_orientation
from .preprocessing import preprocess_batch, iter_preprocessed_batches

LOG = logging.getLogger(__name__)


def _optimized(config, device):
    if config.execution_backend == "optimized":
        return True
    if config.execution_backend == "reference":
        return False
    return torch.device(device).type == "cuda"


def search_orientations(images, config, size, dtype, device):
    if config.adaptive_orientations == 0:
        return np.empty(0), np.zeros(config.num_orientation_bins)
    if _optimized(config, device):
        return _search_orientations_batched(images, config, size, dtype, device)
    return _search_orientations_reference(images, config, size, dtype, device)


def _search_orientations_reference(images, config, size, dtype, device):
    total = np.zeros(config.num_orientation_bins, dtype=np.int64)
    edges = np.linspace(0, 180, config.num_orientation_bins + 1)
    for i, image in enumerate(images):
        x = preprocess_batch([image], size, dtype, device)
        degrees = torch.rad2deg(ridge_orientation(x)).cpu().numpy().ravel()
        if config.orientation_histogram == "fixed":
            count, edges = np.histogram(degrees, bins=config.num_orientation_bins, range=(0, 180))
        else:
            count, edges = np.histogram(degrees, bins=config.num_orientation_bins)
        total += count
        if (i + 1) % 25 == 0:
            LOG.info("Orientation analysis: %d/%d", i + 1, len(images))
    centers = 180 - (edges[:-1] + edges[1:]) / 2
    selected = np.argsort(-total[:-1], kind="stable")[:config.adaptive_orientations]
    return centers[:-1][selected], total


def _search_orientations_batched(images, config, size, dtype, device):
    """Batch ridge-orientation convolutions across images on the compute device."""
    total = np.zeros(config.num_orientation_bins, dtype=np.int64)
    edges = np.linspace(0, 180, config.num_orientation_bins + 1)
    processed = 0
    for x in iter_preprocessed_batches(
            images, size, dtype, device, config.orientation_batch_size,
            config.num_workers, config.pin_memory):
        degrees_batch = torch.rad2deg(ridge_orientation(x)).detach().cpu().numpy()
        # Histogram semantics are intentionally still per-image, particularly
        # for legacy-range where MATLAB/NumPy chooses an image-specific range.
        for degrees in degrees_batch:
            if config.orientation_histogram == "fixed":
                count, edges = np.histogram(degrees.ravel(), bins=config.num_orientation_bins, range=(0, 180))
            else:
                count, edges = np.histogram(degrees.ravel(), bins=config.num_orientation_bins)
            total += count
        processed += len(degrees_batch)
        if processed % 25 == 0 or processed == len(images):
            LOG.info("Orientation analysis (batched): %d/%d", processed, len(images))
    centers = 180 - (edges[:-1] + edges[1:]) / 2
    selected = np.argsort(-total[:-1], kind="stable")[:config.adaptive_orientations]
    return centers[:-1][selected], total


def fixed_gabor_bank(config, *, dtype=torch.float64, device="cpu"):
    coordinates = torch.arange(-config.fixed_half_size, config.fixed_half_size + 1, dtype=dtype, device=device)
    y, x = torch.meshgrid(coordinates, coordinates, indexing="ij")
    envelope = torch.exp(-(x.square() + y.square()) / (2 * config.sigma ** 2)) / (2 * math.pi * config.sigma ** 2)
    kernels, metadata = [], []
    for j in range(config.default_orientations):
        theta = math.pi * j / config.default_orientations
        phase = 2 * math.pi * config.spatial_frequency * (x * math.cos(theta) + y * math.sin(theta))
        kernels.append(envelope * torch.cos(phase))
        metadata.append({"kind": "fixed", "orientation_deg": 180 * j / config.default_orientations,
                         "size": len(coordinates), "spatial_frequency": config.spatial_frequency})
    return kernels, metadata


def multiscale_bank(size, angles_degrees, config, *, dtype=torch.float64, device="cpu"):
    """Yield one scale at a time, retaining MATLAB's scale/orientation order."""
    a0 = 2 ** (1 / config.samples_per_octave)
    max_scale = math.ceil(math.log2(size / 2)) * config.samples_per_octave
    kai = math.sqrt(2 * math.log(2)) * (2 ** config.bandwidth_octaves + 1) / (2 ** config.bandwidth_octaves - 1)
    for scale in range(max_scale + 1):
        kernel_size = 4 * 2 ** scale
        coords = torch.arange(1, kernel_size + 1, dtype=dtype, device=device)
        y, x = torch.meshgrid(coords, coords, indexing="ij")
        center = (4 + 2 ** (-scale)) / 2
        xx = a0 ** (-scale) * x - center * config.b0
        yy = a0 ** (-scale) * y - center * config.b0
        evens, odds, metadata = [], [], []
        for angle in angles_degrees:
            theta = math.radians(float(angle))
            rx = xx * math.cos(theta) + yy * math.sin(theta)
            ry = -xx * math.sin(theta) + yy * math.cos(theta)
            env = (a0 ** (-scale) / math.sqrt(2)) * torch.exp(-(config.aspect_ratio ** 2 * rx.square() + ry.square()) / (2 * config.aspect_ratio ** 2))
            evens.append(env * (torch.cos(kai * rx) - math.exp(-kai ** 2 / 2)))
            odds.append(env * torch.sin(kai * rx))
            metadata.append({"kind": "adaptive", "scale": scale, "orientation_deg": float(angle), "size": kernel_size})
        yield scale, torch.stack(evens + odds)[:, None], metadata


def select_wavelets(images, angles_degrees, config, size, dtype, device):
    if _optimized(config, device):
        return _select_wavelets_batched(images, angles_degrees, config, size, dtype, device)
    return _select_wavelets_reference(images, angles_degrees, config, size, dtype, device)


def _build_bank(angles_degrees, config, size, dtype, device):
    bank = list(multiscale_bank(size, angles_degrees, config, dtype=dtype, device=device))
    n_angles = len(angles_degrees)
    n_candidates = len(bank) * n_angles
    if config.selected_wavelets > n_candidates:
        raise ValueError("selected_wavelets exceeds the candidate bank size.")
    return bank, n_angles, n_candidates


def _finalize_selection(bank, n_angles, counts, config):
    chosen = np.argsort(-counts, kind="stable")[:config.selected_wavelets]
    kernels, metadata = [], []
    all_metadata = [dict(meta, selection_count=int(counts[i * n_angles + j]))
                    for i, (_, _, scale_meta) in enumerate(bank) for j, meta in enumerate(scale_meta)]
    for selected in chosen:
        scale_index, angle_index = divmod(int(selected), n_angles)
        kernels.append(bank[scale_index][1][angle_index, 0].clone())
        metadata.append(dict(all_metadata[selected], candidate_index=int(selected)))
    return kernels, metadata, all_metadata


def _select_wavelets_reference(images, angles_degrees, config, size, dtype, device):
    bank, n_angles, n_candidates = _build_bank(angles_degrees, config, size, dtype, device)
    counts = np.zeros(n_candidates, dtype=np.int64)
    candidate_ids = None
    for index, image in enumerate(images):
        x = preprocess_batch([image], size, dtype, device)
        powers, ids = [], []
        for scale_index, (scale, weights, _) in enumerate(bank):
            output = myconv2(x, weights, scale, config.convolution_backend)[0]
            power = output[:n_angles].square() + output[n_angles:].square()
            powers.append(power.detach().cpu().numpy().ravel())
            if candidate_ids is None:
                ids.append(np.repeat(np.arange(scale_index * n_angles, (scale_index + 1) * n_angles), power.shape[-2] * power.shape[-1]))
        if candidate_ids is None:
            candidate_ids = np.concatenate(ids)
        all_power = np.concatenate(powers)
        top = np.argsort(-all_power, kind="stable")[:config.num_wavelet_responses]
        counts += np.bincount(candidate_ids[top], minlength=n_candidates)
        if (index + 1) % 10 == 0 or index + 1 == len(images):
            LOG.info("Adaptive Gabor selection: %d/%d", index + 1, len(images))
    return _finalize_selection(bank, n_angles, counts, config)


def _select_wavelets_batched(images, angles_degrees, config, size, dtype, device):
    """Apply every orientation of each scale to an image batch and GPU-topk globally."""
    bank, n_angles, n_candidates = _build_bank(angles_degrees, config, size, dtype, device)
    counts = torch.zeros(n_candidates, dtype=torch.int64, device=device)
    candidate_ids = None
    processed = 0
    for x in iter_preprocessed_batches(
            images, size, dtype, device, config.gabor_tuning_batch_size,
            config.num_workers, config.pin_memory):
        flattened_powers = []
        ids = []
        for scale_index, (scale, weights, _) in enumerate(bank):
            output = myconv2(x, weights, scale, config.convolution_backend)
            power = output[:, :n_angles].square() + output[:, n_angles:].square()
            pixels = power.shape[-2] * power.shape[-1]
            flattened_powers.append(power.flatten(2).reshape(len(x), -1))
            if candidate_ids is None:
                ids.append(torch.arange(scale_index * n_angles, (scale_index + 1) * n_angles,
                                        device=device, dtype=torch.long).repeat_interleave(pixels))
        if candidate_ids is None:
            candidate_ids = torch.cat(ids)
        all_power = torch.cat(flattened_powers, dim=1)
        k = min(config.num_wavelet_responses, all_power.shape[1])
        top = torch.topk(all_power, k=k, dim=1, largest=True, sorted=False).indices
        selected_ids = candidate_ids[top].reshape(-1)
        counts += torch.bincount(selected_ids, minlength=n_candidates)
        processed += len(x)
        if processed % 10 == 0 or processed == len(images):
            LOG.info("Adaptive Gabor selection (batched): %d/%d", processed, len(images))
    return _finalize_selection(bank, n_angles, counts.cpu().numpy(), config)
