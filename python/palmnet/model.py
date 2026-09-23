"""PCA -> fixed+adaptive Gabor -> sign hashing -> sparse block histograms."""
import logging
from pathlib import Path
import numpy as np
from scipy import sparse
import torch
from torch import nn
from torch.nn import functional as F
from .config import PalmConfig
from .gabor import fixed_gabor_bank, search_orientations, select_wavelets
from .hashing import block_geometry, hashing_histogram
from .ops import imfilter_conv_replicate
from .preprocessing import as_image_list, infer_size, preprocess_batch, iter_preprocessed_batches

LOG = logging.getLogger(__name__)


def resolve_device(device="auto"):
    if str(device) == "auto":
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    result = torch.device(device)
    if result.type == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA was requested but is unavailable. Install a CUDA-enabled PyTorch build or use --device cpu.")
    return result


def _pca_conv(x, weight, padding):
    return F.conv2d(x, weight, padding=padding)


class _GaborGroup(nn.Module):
    def __init__(self, weights, indices):
        super().__init__()
        self.register_buffer("weights", weights)
        self.register_buffer("indices", torch.tensor(indices, device=weights.device, dtype=torch.long))


class PalmPCAGabor(nn.Module):
    """Classical, unsupervised PalmNet feature extractor implemented in PyTorch.

    The optimized backend only changes execution: covariance accumulation,
    orientation analysis, adaptive Gabor selection and feature convolutions are
    batched/vectorized. The reference backend keeps the original image-wise
    implementation for parity/debugging.
    """
    def __init__(self, config: PalmConfig | None = None, device="auto"):
        super().__init__()
        self.config = PalmConfig(**(config or PalmConfig()).to_dict()).validate()
        device = resolve_device(device)
        dtype = getattr(torch, self.config.dtype)
        self.register_buffer("pca_weight", torch.empty(0, 1, self.config.pca_patch_size,
                                                        self.config.pca_patch_size, dtype=dtype, device=device))
        self.register_buffer("_image_size", torch.tensor(self.config.image_size or 0, device=device))
        self.gabor_groups = nn.ModuleList()
        self.fit_info = {}
        self.gabor_metadata = []
        self._compiled_pca = None
        if self.config.compile_dense:
            self.enable_compile()

    @property
    def device(self):
        return self.pca_weight.device

    @property
    def dtype(self):
        return self.pca_weight.dtype

    @property
    def image_size(self):
        return int(self._image_size.item())

    @property
    def num_pca_filters(self):
        return int(self.pca_weight.shape[0])

    @property
    def num_gabor_filters(self):
        return sum(len(group.indices) for group in self.gabor_groups)

    @property
    def optimized(self):
        if self.config.execution_backend == "optimized":
            return True
        if self.config.execution_backend == "reference":
            return False
        return self.device.type == "cuda"

    @property
    def feature_dimension(self):
        if not self.image_size or not self.num_pca_filters or not self.num_gabor_filters:
            raise RuntimeError("Fit or load the model first.")
        *_, ny, nx = block_geometry(self.image_size, self.image_size,
                                     self.config.hist_block_size, self.config.block_overlap)
        return self.num_pca_filters * ny * nx * 2 ** self.num_gabor_filters

    def enable_compile(self):
        """Compile the dense PCA convolution when torch.compile is available.

        Sparse histogram construction intentionally remains eager because sparse
        graph support varies across PyTorch releases.
        """
        if not hasattr(torch, "compile"):
            LOG.warning("torch.compile is unavailable in this PyTorch build; continuing eagerly.")
            return self
        try:
            self._compiled_pca = torch.compile(_pca_conv, dynamic=False)
            LOG.info("torch.compile enabled for the dense PCA convolution stage.")
        except Exception as exc:  # compilation can be platform/build dependent
            LOG.warning("Could not enable torch.compile (%s); continuing eagerly.", exc)
            self._compiled_pca = None
        return self

    def _pca_covariance_reference(self, images, size):
        k = self.config.pca_patch_size
        covariance = torch.zeros(k * k, k * k, dtype=torch.float64, device=self.device)
        generator = torch.Generator(device="cpu").manual_seed(self.config.seed)
        patch_count = 0
        for index, image in enumerate(images):
            x = preprocess_batch([image], size, self.dtype, self.device).to(torch.float64)
            patches = F.unfold(x, kernel_size=k)[0]
            patches = patches.reshape(k, k, -1).transpose(0, 1).reshape(k * k, -1)
            if self.config.max_patches_per_image is not None and patches.shape[1] > self.config.max_patches_per_image:
                selected = torch.randperm(patches.shape[1], generator=generator)[:self.config.max_patches_per_image].to(self.device)
                patches = patches[:, selected]
            for chunk in patches.split(self.config.pca_patch_chunk, dim=1):
                chunk = chunk - chunk.mean(dim=0, keepdim=True)
                covariance.addmm_(chunk, chunk.T)
                patch_count += chunk.shape[1]
            if (index + 1) % 25 == 0 or index + 1 == len(images):
                LOG.info("PCA covariance (reference): %d/%d", index + 1, len(images))
        return covariance, patch_count

    def _pca_covariance_optimized(self, images, size):
        """Batch image unfolding and accumulate covariance with large GEMMs."""
        k = self.config.pca_patch_size
        dim = k * k
        covariance = torch.zeros(dim, dim, dtype=torch.float64, device=self.device)
        generator = torch.Generator(device="cpu").manual_seed(self.config.seed)
        patch_count = 0
        processed = 0
        for x in iter_preprocessed_batches(
                images, size, self.dtype, self.device, self.config.pca_image_batch_size,
                self.config.num_workers, self.config.pin_memory):
            x = x.to(torch.float64)
            patches = F.unfold(x, kernel_size=k)  # [B,k*k,L], row-major patch vectors
            b, _, locations = patches.shape
            # MATLAB im2col vectorizes each patch column-major.
            patches = patches.reshape(b, k, k, locations).transpose(1, 2).reshape(b, dim, locations)
            if self.config.max_patches_per_image is not None and locations > self.config.max_patches_per_image:
                selected_batches = []
                for i in range(b):
                    selected = torch.randperm(locations, generator=generator)[:self.config.max_patches_per_image].to(self.device)
                    selected_batches.append(patches[i, :, selected])
                matrix = torch.cat(selected_batches, dim=1)
            else:
                matrix = patches.permute(1, 0, 2).reshape(dim, -1)
            for chunk in matrix.split(self.config.pca_patch_chunk, dim=1):
                chunk = chunk - chunk.mean(dim=0, keepdim=True)
                covariance.addmm_(chunk, chunk.T)
                patch_count += chunk.shape[1]
            processed += b
            if processed % 25 == 0 or processed == len(images):
                LOG.info("PCA covariance (batched GEMM): %d/%d", processed, len(images))
        return covariance, patch_count

    @torch.no_grad()
    def fit(self, images):
        images = as_image_list(images)
        size = self.config.image_size or infer_size(images[0])
        if size < max(4, self.config.pca_patch_size, *self.config.hist_block_size):
            raise ValueError("Image size is smaller than the PCA patch or histogram block.")
        self._image_size.fill_(size)
        if self.config.orientation_histogram == "legacy-range" and self.config.adaptive_orientations:
            LOG.warning("Using source-style per-image orientation histograms; NumPy bin edges approximate MATLAB histcounts. See README.")
        LOG.info("Fitting first-stage PCA on %d training images, size=%dx%d; execution=%s; response dtype=%s",
                 len(images), size, size, "optimized" if self.optimized else "reference", str(self.dtype).split(".")[-1])
        if self.optimized:
            covariance, patch_count = self._pca_covariance_optimized(images, size)
        else:
            covariance, patch_count = self._pca_covariance_reference(images, size)
        covariance /= patch_count
        eigenvalues, vectors = torch.linalg.eigh(covariance)
        eigenvalues = eigenvalues.flip(0).clamp_min(0)
        vectors = vectors.flip(1)
        total = eigenvalues.sum()
        if not torch.isfinite(total) or total <= 0:
            raise ValueError("Training patches have zero variance. Check images/preprocessing.")
        cumulative = torch.cumsum(eigenvalues, 0) / total
        filters = self.config.pca_filters
        if self.config.retained_variance is not None:
            filters = min(self.config.pca_patch_size ** 2,
                          int(torch.searchsorted(cumulative, cumulative.new_tensor(self.config.retained_variance)).item()) + 1)
        vectors = vectors[:, :filters]
        maxima = vectors.abs().argmax(dim=0)
        signs = vectors[maxima, torch.arange(filters, device=self.device)].sign()
        vectors *= torch.where(signs == 0, torch.ones_like(signs), signs)
        k = self.config.pca_patch_size
        self.pca_weight = vectors.T.reshape(filters, k, k).transpose(-2, -1).unsqueeze(1).contiguous().to(self.dtype)
        retained = float(cumulative[filters - 1])
        LOG.info("PCA: %d filters, %.4f%% retained variance, %d patches", filters, 100 * retained, patch_count)

        LOG.info("Searching ridge orientations on original preprocessed training images (not PCA maps)")
        adaptive_angles, angle_counts = search_orientations(images, self.config, size, self.dtype, self.device)
        fixed_angles = np.arange(self.config.default_orientations) * 180 / self.config.default_orientations
        all_angles = np.unique(np.concatenate([fixed_angles, adaptive_angles]))
        kernels, metadata = fixed_gabor_bank(self.config, dtype=self.dtype, device=self.device)
        candidate_metadata = []
        if self.config.selected_wavelets:
            extra, extra_metadata, candidate_metadata = select_wavelets(
                images, all_angles, self.config, size, self.dtype, self.device)
            kernels.extend(extra)
            metadata.extend(extra_metadata)
        self._set_gabor(kernels, metadata, normalized=False)
        self.fit_info = {
            "training_images": len(images), "pca_patches": patch_count,
            "retained_variance": retained, "pca_eigenvalues": eigenvalues.cpu().tolist(),
            "adaptive_orientations_deg": adaptive_angles.tolist(), "orientation_counts": angle_counts.tolist(),
            "candidate_filters": candidate_metadata, "selected_filters": metadata,
            "orientation_histogram": self.config.orientation_histogram,
            "execution_backend": "optimized" if self.optimized else "reference",
            "response_dtype": str(self.dtype).split(".")[-1],
            "pca_training_dtype": "float64",
            "training_rule": "PCA on valid mean-removed patches; Gabor selection on original training images",
        }
        LOG.info("Fitted: L1=%d, L2=%d, feature dimension=%s (sparse)",
                 filters, self.num_gabor_filters, f"{self.feature_dimension:,}")
        return self

    def _set_gabor(self, kernels, metadata=None, normalized=False):
        if not 1 <= len(kernels) <= 30:
            raise ValueError("Expected 1..30 second-stage kernels.")
        grouped = {}
        for index, kernel in enumerate(kernels):
            kernel = torch.as_tensor(kernel, device=self.device, dtype=self.dtype)
            if kernel.ndim != 2 or not torch.isfinite(kernel).all():
                raise ValueError("Gabor kernels must be finite 2-D arrays.")
            if not normalized:
                maximum = kernel.max()
                if maximum <= 0:
                    raise ValueError("A Gabor kernel has no positive maximum.")
                kernel = kernel / maximum
            grouped.setdefault(tuple(kernel.shape), []).append((index, kernel))
        self.gabor_groups = nn.ModuleList([
            _GaborGroup(torch.stack([kernel for _, kernel in group])[:, None], [index for index, _ in group])
            for group in grouped.values()
        ])
        self.gabor_metadata = metadata or [{} for _ in kernels]

    def _check_input(self, x):
        if not self.num_pca_filters or not self.num_gabor_filters:
            raise RuntimeError("Call fit(), load(), or from_matlab_fixture() before extracting features.")
        if x.ndim != 4 or x.shape[0] == 0 or tuple(x.shape[1:]) != (1, self.image_size, self.image_size):
            raise ValueError(f"Expected preprocessed [N,1,{self.image_size},{self.image_size}] input, got {tuple(x.shape)}.")
        if not torch.isfinite(x).all():
            raise ValueError("Input contains NaN/Inf.")
        return x.to(device=self.device, dtype=self.dtype)

    def pca_responses(self, x):
        x = self._check_input(x)
        weight = self.pca_weight - self.pca_weight.mean((-2, -1), keepdim=True)
        fn = self._compiled_pca if self._compiled_pca is not None else _pca_conv
        return fn(x, weight, self.config.pca_patch_size // 2)

    def _response_chunks(self, stage1):
        # Flattening [N,L1] into the convolution batch computes every PCA-branch
        # x Gabor-filter combination in parallel. Gabor kernels are grouped only
        # because adaptive scales have different spatial support sizes.
        flattened = stage1.reshape(-1, 1, self.image_size, self.image_size)
        for group in self.gabor_groups:
            for start in range(0, len(flattened), self.config.response_batch_size):
                response = imfilter_conv_replicate(
                    flattened[start:start + self.config.response_batch_size],
                    group.weights, self.config.convolution_backend)
                yield start, group.indices, response

    @torch.no_grad()
    def hash_codes(self, x):
        stage1 = self.pca_responses(x)
        n, branches, h, w = stage1.shape
        codes = torch.zeros(n * branches, h, w, dtype=torch.long, device=self.device)
        for start, indices, response in self._response_chunks(stage1):
            bits = (2 ** (self.num_gabor_filters - 1 - indices))[None, :, None, None]
            codes[start:start + len(response)] += ((response > 0).long() * bits).sum(1)
        return codes.reshape(n, branches, h, w)

    @torch.no_grad()
    def forward(self, x):
        return hashing_histogram(self.hash_codes(x), self.num_gabor_filters, self.config, self.dtype)

    @torch.no_grad()
    def intermediate_responses(self, x):
        first = self.pca_responses(x)
        n, branches, h, w = first.shape
        second = torch.empty(n * branches, self.num_gabor_filters, h, w,
                             dtype=self.dtype, device=self.device)
        for start, indices, response in self._response_chunks(first):
            second[start:start + len(response), indices] = response
        return first, second.reshape(n, branches, self.num_gabor_filters, h, w)

    def preprocess(self, images):
        if not self.image_size:
            raise RuntimeError("Fit/load the model first to establish the resize target.")
        return preprocess_batch(as_image_list(images), self.image_size, self.dtype, self.device)

    @torch.no_grad()
    def transform(self, images, batch_size=1, num_workers=None):
        images = as_image_list(images)
        if batch_size < 1:
            raise ValueError("batch_size must be positive.")
        workers = self.config.num_workers if num_workers is None else num_workers
        matrices = []
        processed = 0
        for x in iter_preprocessed_batches(images, self.image_size, self.dtype, self.device,
                                           batch_size, workers, self.config.pin_memory):
            output = self(x).coalesce().cpu()
            ij = output.indices().numpy()
            matrices.append(sparse.csr_matrix((output.values().numpy(), (ij[0], ij[1])), shape=output.shape))
            processed += len(x)
            if processed % 25 == 0 or processed == len(images):
                LOG.info("Feature extraction: %d/%d", processed, len(images))
        return sparse.vstack(matrices, format="csr")

    def fit_transform(self, images, batch_size=1):
        images = as_image_list(images)
        self.fit(images)
        return self.transform(images, batch_size)

    def save(self, path):
        _ = self.feature_dimension
        kernels = [None] * self.num_gabor_filters
        for group in self.gabor_groups:
            for index, kernel in zip(group.indices.tolist(), group.weights[:, 0]):
                kernels[index] = kernel.detach().cpu()
        config = self.config.to_dict()
        config["dtype"] = str(self.dtype).split(".")[-1]
        # Compilation is a runtime choice, not part of the learned model.
        config["compile_dense"] = False
        payload = {"format": "PalmPCAGabor", "version": 2, "config": config,
                   "image_size": self.image_size, "pca_weight": self.pca_weight.detach().cpu(),
                   "gabor_kernels": kernels, "gabor_metadata": self.gabor_metadata, "fit_info": self.fit_info}
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(payload, path)

    @classmethod
    def load(cls, path, device="auto"):
        payload = torch.load(path, map_location="cpu", weights_only=True)
        if payload.get("format") != "PalmPCAGabor" or payload.get("version") not in (1, 2):
            raise ValueError("Not a supported PalmPCAGabor checkpoint.")
        # Version-1 checkpoints predate parallel-execution fields; dataclass defaults fill them.
        model = cls(PalmConfig(**payload["config"]), device)
        model._image_size.fill_(int(payload["image_size"]))
        model.pca_weight = payload["pca_weight"].to(model.device, model.dtype)
        model._set_gabor(payload["gabor_kernels"], payload["gabor_metadata"], normalized=True)
        model.fit_info = payload["fit_info"]
        model.eval()
        return model

    @classmethod
    def from_matlab_fixture(cls, path, device="cpu"):
        """Import exact PCA/Gabor weights from matlab/export_pytorch_fixture.m."""
        from scipy.io import loadmat
        fixture = loadmat(path)
        if int(np.asarray(fixture.get("has_pyramid", [[0]])).item()):
            raise ValueError("Spatial pyramids are outside the active supplied pipeline.")
        v = np.asarray(fixture["pca_vectors"], dtype=np.float64)
        k = int(round(np.sqrt(v.shape[0])))
        if k * k != v.shape[0]:
            raise ValueError("Only grayscale square PCA patches are supported.")
        kernels = list(fixture["gabor_kernels"].ravel())
        cfg = PalmConfig(image_size=int(fixture["input_image"].shape[0]), pca_patch_size=k,
                         pca_filters=v.shape[1], default_orientations=len(kernels), selected_wavelets=0,
                         hist_block_size=tuple(np.asarray(fixture["hist_block_size"]).astype(int).ravel()),
                         block_overlap=float(np.asarray(fixture["block_overlap"]).item()),
                         convolution_backend="direct", execution_backend="reference")
        model = cls(cfg, device)
        weights = np.stack([v[:, i].reshape(k, k, order="F") for i in range(v.shape[1])])[:, None]
        model.pca_weight = torch.as_tensor(weights.copy(), device=model.device, dtype=model.dtype)
        model._set_gabor([np.real(a) for a in kernels], normalized=False)
        model.fit_info = {"imported_matlab_fixture": str(Path(path).name)}
        model.eval()
        return model
