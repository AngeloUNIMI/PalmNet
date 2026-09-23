"""Binary hashing and sparse local histograms, without dense 2**L arrays."""
import torch


def block_geometry(height, width, block_size, overlap):
    bh, bw = block_size
    sy, sx = (int((1 - overlap) * b + .5) for b in block_size)
    if height < bh or width < bw:
        raise ValueError(f"Histogram block {block_size} exceeds image {(height, width)}.")
    if min(sy, sx) < 1:
        raise ValueError("Histogram stride must be positive.")
    ny, nx = (height - bh) // sy + 1, (width - bw) // sx + 1
    return bh, bw, sy, sx, ny, nx


def hashing_histogram(codes, num_gabor_filters, config, dtype=torch.float64):
    """codes [N,L1,H,W] -> sparse COO [N,D]; no border padding for blocks.

    MATLAB f=vec([Bhist{:}]') is BIN-MAJOR, then PCA branch, then block.
    The block traversal is column-major (rows vary fastest).
    """
    n, branches, height, width = codes.shape
    bh, bw, sy, sx, ny, nx = block_geometry(height, width, config.hist_block_size, config.block_overlap)
    blocks = ny * nx
    bins = 2 ** num_gabor_filters
    dim = branches * blocks * bins
    if dim >= 2 ** 63:
        raise ValueError("Feature indices exceed int64 capacity.")
    patches = codes.unfold(2, bh, sy).unfold(3, bw, sx)
    patches = patches.permute(0, 1, 3, 2, 4, 5).reshape(n, branches * blocks, bh * bw)
    position = torch.arange(branches * blocks, device=codes.device)[None, :, None]
    if config.feature_order == "matlab":
        columns = patches * (branches * blocks) + position
    else:
        columns = position * bins + patches
    rows = torch.arange(n, device=codes.device)[:, None, None].expand_as(columns)
    if config.histogram_normalization == "matlab":
        scale = bins / (bh * bw)
    elif config.histogram_normalization == "l1":
        scale = 1 / (bh * bw)
    else:
        scale = 1
    indices = torch.stack([rows.reshape(-1), columns.reshape(-1)])
    # Coalesce integer counts BEFORE normalization to avoid repeated float
    # addition changing the source's count-then-normalize operation.
    values = torch.ones(indices.shape[1], dtype=torch.int64, device=codes.device)
    counted = torch.sparse_coo_tensor(indices, values, (n, dim)).coalesce()
    return torch.sparse_coo_tensor(counted.indices(), counted.values().to(dtype) * scale,
                                   counted.shape, is_coalesced=True)
