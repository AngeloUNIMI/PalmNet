"""Filtering primitives. PCA/tuning use correlation; final Gabor uses convolution."""
import math
import torch
from torch.nn import functional as F
from scipy.fft import next_fast_len


def correlate_valid(x, kernels, stride=1, backend="auto"):
    """x: [B,1,H,W], kernels: [K,1,h,w]. Real-valued valid correlation."""
    h, w = kernels.shape[-2:]
    if x.shape[-2] < h or x.shape[-1] < w:
        raise ValueError("A valid correlation requires image >= kernel.")
    use_fft = backend == "fft" or (backend == "auto" and stride == 1 and max(h, w) >= 15)
    if not use_fft:
        return F.conv2d(x, kernels, stride=stride)
    # Linear convolution with a flipped kernel equals cross-correlation.
    H, W = x.shape[-2:]
    shape = (next_fast_len(H + h - 1), next_fast_len(W + w - 1))
    xf = torch.fft.rfft2(x[:, 0], s=shape)
    kf = torch.fft.rfft2(kernels[:, 0].flip((-2, -1)), s=shape)
    full = torch.fft.irfft2(xf[:, None] * kf[None], s=shape)
    return full[..., h - 1:H:stride, w - 1:W:stride]


def imfilter_conv_replicate(x, kernels, backend="auto"):
    """MATLAB imfilter(x,h,'replicate','same','conv') origin convention.

    The original kernel's one-based origin is floor((size(h)+1)/2).
    Even kernels therefore need one extra sample BEFORE the image after
    rotating the kernel for correlation. This is NOT F.pad(..., 'same').
    """
    h, w = kernels.shape[-2:]
    xpad = F.pad(x, (w // 2, (w - 1) // 2, h // 2, (h - 1) // 2), mode="replicate")
    return correlate_valid(xpad, kernels.flip((-2, -1)), backend=backend)


def scale_step(scale):
    return 1 if scale == 0 else 3 * 2 ** (scale - 1)


def myconv2(x, kernels, scale, backend="auto"):
    """Vectorized port of util/myConv2.m, including its unusual canvas size."""
    H, W = x.shape[-2:]
    h, w = kernels.shape[-2:]
    if H != W or h != w:
        raise ValueError("myConv2 in the supplied MATLAB program requires square images/filters.")
    step = scale_step(scale)
    number = 2 * math.ceil(((H - h) / 2 + 1) / step) + 1
    canvas = step * (number - 1) + h
    if canvas < H or (canvas - H) % 2 or number < 1:
        raise ValueError("Invalid myConv2 canvas. Use the source's power-of-two image sizes and N=1.")
    pad = (canvas - H) // 2
    return correlate_valid(F.pad(x, (pad, pad, pad, pad)), kernels, step, backend)


def gaussian_kernel(sigma, size, *, dtype, device):
    a = torch.arange(size, dtype=dtype, device=device) - (size - 1) / 2
    yy, xx = torch.meshgrid(a, a, indexing="ij")
    g = torch.exp(-(xx.square() + yy.square()) / (2 * sigma * sigma))
    g[g < torch.finfo(dtype).eps * g.max()] = 0
    return (g / g.sum())[None, None]


def ridge_orientation(x):
    """Port of the supplied Kovesi ridgeorient(..., .1, 1.5, 1.5).

    x is [B,1,H,W]; returns clockwise ridge angles in [0, pi].
    See THIRD_PARTY_NOTICES.txt for derivative5 attribution.
    """
    p = x.new_tensor([.037659, .249153, .426375, .249153, .037659])
    d = x.new_tensor([.109604, .276691, 0, -.276691, -.109604])
    # gaussfilt(...,.1) uses a one-element kernel, hence it is the identity.
    deriv = torch.stack([p[:, None] * d[None, :], d[:, None] * p[None, :]])[:, None]
    gradients = F.conv2d(x, deriv.flip((-2, -1)), padding=2)
    gx, gy = gradients[:, :1], gradients[:, 1:2]
    g = gaussian_kernel(1.5, 9, dtype=x.dtype, device=x.device)
    gxx = F.conv2d(gx.square(), g, padding=4)
    gxy = 2 * F.conv2d(gx * gy, g, padding=4)
    gyy = F.conv2d(gy.square(), g, padding=4)
    denominator = torch.sqrt(gxy.square() + (gxx - gyy).square()) + torch.finfo(x.dtype).eps
    sine = F.conv2d(gxy / denominator, g, padding=4)
    cosine = F.conv2d((gxx - gyy) / denominator, g, padding=4)
    return math.pi / 2 + torch.atan2(sine, cosine) / 2
