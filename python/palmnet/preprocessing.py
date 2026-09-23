"""Explicit grayscale/uint8 conversion, bicubic resizing, mean subtraction, and batched loading."""
from pathlib import Path
import math
import numpy as np
from PIL import Image
import torch
from torch.utils.data import DataLoader, Dataset


class _PathImageDataset(Dataset):
    """Decode images in DataLoader workers; kept top-level for Windows spawn."""
    def __init__(self, paths):
        self.paths = [str(Path(p)) for p in paths]

    def __len__(self):
        return len(self.paths)

    def __getitem__(self, index):
        return read_uint8(self.paths[index])


def _list_collate(batch):
    # Images may have different native sizes, so do not stack before resizing.
    return batch


def as_image_list(images):
    if isinstance(images, (str, Path)):
        return [images]
    if isinstance(images, (np.ndarray, torch.Tensor)):
        if images.ndim == 2:
            return [images]
        if images.ndim == 4:  # NCHW
            if len(images) == 0:
                raise ValueError("No input images.")
            return list(images)
        if images.ndim == 3 and (images.shape[0] in (1, 3) or images.shape[-1] in (1, 3)):
            return [images]
        raise ValueError("Use NCHW for batches or a list of 2-D grayscale images; NHW is ambiguous.")
    result = list(images)
    if not result:
        raise ValueError("No input images.")
    return result


def read_uint8(image):
    if isinstance(image, (str, Path)):
        with Image.open(image) as im:
            # Palette images must be decoded, not interpreted as intensity indices.
            if im.mode in ("P", "RGBA", "LA", "CMYK"):
                im = im.convert("RGB")
            a = np.asarray(im).copy()
    elif isinstance(image, torch.Tensor):
        a = image.detach().cpu().numpy()
    else:
        a = np.asarray(image)
    if a.ndim == 3 and a.shape[0] in (1, 3) and a.shape[-1] not in (1, 3):
        a = np.moveaxis(a, 0, -1)
    if a.ndim == 3 and a.shape[-1] == 1:
        a = a[..., 0]
    if a.ndim not in (2, 3) or (a.ndim == 3 and a.shape[-1] != 3):
        raise ValueError(f"Expected gray or RGB image, got {a.shape}.")
    original_dtype = a.dtype
    a = a.astype(np.float64)
    if not np.isfinite(a).all():
        raise ValueError("Images cannot contain NaN/Inf.")
    if original_dtype == np.bool_:
        a *= 255
    elif np.issubdtype(original_dtype, np.floating):
        if a.min() < 0 or a.max() > 1:
            raise ValueError("Raw float images must be in [0,1], matching im2uint8. For [0,255], cast to uint8; for preprocessed tensors, use forward().")
        a *= 255
    elif original_dtype != np.uint8:
        if original_dtype != np.uint16:
            raise ValueError(f"Unsupported integer image type {original_dtype}; convert to uint8 explicitly.")
        a *= 255 / 65535
    if a.ndim == 3:
        a = a @ np.array([.298936021293775, .587043074451121, .114020904255103])
    return np.floor(np.clip(a, 0, 255) + .5).astype(np.uint8)


def _cubic(x):
    z = x.abs()
    return ((1.5 * z - 2.5) * z * z + 1) * (z <= 1) + (((-.5 * z + 2.5) * z - 4) * z + 2) * ((z > 1) & (z < 2))


def _resize_axis(x, output_size, axis):
    """Half-pixel Keys cubic, antialiasing on reduction, symmetric extension."""
    source_size = x.shape[axis]
    if source_size == output_size:
        return x
    scale = output_size / source_size
    stretch = min(scale, 1.0)
    width = 4 / stretch
    coordinate = (torch.arange(output_size, device=x.device, dtype=x.dtype) + .5) / scale - .5
    left = torch.floor(coordinate - width / 2).long()
    indices = left[:, None] + torch.arange(math.ceil(width) + 2, device=x.device)
    weights = stretch * _cubic((coordinate[:, None] - indices) * stretch)
    weights /= weights.sum(1, keepdim=True)
    # Symmetric (not reflect) extension repeats the edge sample.
    indices = indices.remainder(2 * source_size)
    indices = torch.where(indices < source_size, indices, 2 * source_size - indices - 1)
    moved = x.movedim(axis, 0)
    expanded = moved[indices]
    weights = weights.reshape(*weights.shape, *((1,) * (expanded.ndim - 2)))
    return (expanded * weights).sum(1).movedim(0, axis)


def resize_bicubic(x, size):
    return _resize_axis(_resize_axis(x, size, -2), size, -1)


def infer_size(image):
    h = read_uint8(image).shape[0]
    return 2 ** int(math.floor(math.log2(h)))


def preprocess_one(image, size, dtype=torch.float64, device="cpu"):
    a = torch.as_tensor(read_uint8(image), device=device, dtype=dtype)
    a = resize_bicubic(a, size)
    return (a - a.mean())[None]


def preprocess_batch(images, size, dtype=torch.float64, device="cpu"):
    return torch.stack([preprocess_one(a, size, dtype, device) for a in images])


def iter_preprocessed_batches(images, size, dtype=torch.float64, device="cpu", batch_size=1,
                              num_workers=0, pin_memory=True):
    """Yield [B,1,size,size] preprocessed batches.

    When every item is a path and num_workers>0, image decoding is parallelized
    with a PyTorch DataLoader. Resizing remains on the selected compute device.
    This keeps Windows worker processes away from CUDA state.
    """
    images = as_image_list(images)
    if batch_size < 1 or num_workers < 0:
        raise ValueError("batch_size must be positive and num_workers must be >= 0.")
    all_paths = all(isinstance(item, (str, Path)) for item in images)
    if num_workers > 0 and all_paths:
        loader = DataLoader(
            _PathImageDataset(images), batch_size=batch_size, shuffle=False,
            num_workers=num_workers, collate_fn=_list_collate,
            pin_memory=bool(pin_memory and torch.device(device).type == "cuda"),
            persistent_workers=False,
        )
        for raw in loader:
            # raw already contains decoded uint8 arrays, so read_uint8 is cheap.
            yield preprocess_batch(raw, size, dtype, device)
        return
    for start in range(0, len(images), batch_size):
        yield preprocess_batch(images[start:start + batch_size], size, dtype, device)
