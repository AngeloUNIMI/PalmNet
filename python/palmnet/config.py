"""Parameters corresponding to paramsPCAGaborTuning_v1.m plus execution controls."""
from dataclasses import asdict, dataclass
from pathlib import Path
import json


@dataclass
class PalmConfig:
    image_size: int | None = None
    pca_patch_size: int = 15
    pca_filters: int = 15
    retained_variance: float | None = None  # None = fixed filter count
    num_orientation_bins: int = 45
    default_orientations: int = 10
    adaptive_orientations: int = 10
    orientation_histogram: str = "legacy-range"
    sigma: float = 5.6179
    spatial_frequency: float = 0.11  # MATLAB calls this 'wavelength', but uses frequency
    fixed_half_size: int = 17
    samples_per_octave: int = 1
    b0: float = 1.0
    bandwidth_octaves: float = 1.5
    aspect_ratio: float = 1.0
    num_wavelet_responses: int = 10000
    selected_wavelets: int = 5
    hist_block_size: tuple[int, int] = (23, 23)
    block_overlap: float = 0.0
    histogram_normalization: str = "matlab"  # per-block sum = 2**L2
    feature_order: str = "matlab"  # bin, PCA branch, block (row varies fastest)

    # Numeric/execution controls. PCA covariance/eigh always remain float64.
    dtype: str = "float64"  # response/filter precision; float32 = fast mode
    execution_backend: str = "auto"  # auto / reference / optimized
    convolution_backend: str = "auto"  # auto / direct / fft
    compile_dense: bool = False
    num_workers: int = 0
    pin_memory: bool = True

    # Batch/chunk sizes for independent stages.
    pca_image_batch_size: int = 8
    pca_patch_chunk: int = 262144
    orientation_batch_size: int = 16
    gabor_tuning_batch_size: int = 4
    max_patches_per_image: int | None = None  # optional approximation; all by default
    response_batch_size: int = 64
    seed: int = 0

    def validate(self):
        if self.image_size is not None and (self.image_size < 4 or self.image_size & (self.image_size - 1)):
            raise ValueError("image_size must be a power of two >= 4, or None.")
        if self.pca_patch_size < 1 or self.pca_patch_size % 2 != 1:
            raise ValueError("pca_patch_size must be a positive odd number.")
        if not 1 <= self.pca_filters <= self.pca_patch_size ** 2:
            raise ValueError("pca_filters must be between 1 and pca_patch_size**2.")
        if self.retained_variance is not None and not 0 < self.retained_variance <= 1:
            raise ValueError("retained_variance must be in (0, 1].")
        if self.num_orientation_bins < 2 or not 0 <= self.adaptive_orientations < self.num_orientation_bins:
            raise ValueError("adaptive_orientations must be smaller than num_orientation_bins.")
        if self.default_orientations < 1 or self.selected_wavelets < 0:
            raise ValueError("At least one fixed orientation is required; selected_wavelets must be >= 0.")
        if self.default_orientations + self.selected_wavelets > 30:
            raise ValueError("At most 30 second-stage filters are supported (exponential histogram size).")
        if self.orientation_histogram not in ("legacy-range", "fixed"):
            raise ValueError("orientation_histogram must be legacy-range or fixed.")
        if self.samples_per_octave != 1:
            raise ValueError("Only the supplied N=1 setting is supported; the MATLAB support-size formula is inconsistent with general N.")
        if min(self.sigma, self.spatial_frequency, self.b0, self.bandwidth_octaves, self.aspect_ratio) <= 0:
            raise ValueError("Gabor parameters must be positive.")
        if self.fixed_half_size < 1 or self.num_wavelet_responses < 1:
            raise ValueError("fixed_half_size and num_wavelet_responses must be positive.")
        self.hist_block_size = tuple(int(v) for v in self.hist_block_size)
        if len(self.hist_block_size) != 2 or min(self.hist_block_size) < 1:
            raise ValueError("hist_block_size must contain two positive integers.")
        if not 0 <= self.block_overlap < 1:
            raise ValueError("block_overlap must be in [0, 1).")
        if any(int((1 - self.block_overlap) * v + .5) < 1 for v in self.hist_block_size):
            raise ValueError("The requested overlap produces a zero histogram stride.")
        if self.dtype not in ("float32", "float64"):
            raise ValueError("dtype must be float32 or float64.")
        if self.execution_backend not in ("auto", "reference", "optimized"):
            raise ValueError("execution_backend must be auto, reference, or optimized.")
        if self.convolution_backend not in ("auto", "direct", "fft"):
            raise ValueError("convolution_backend must be auto, direct, or fft.")
        if self.histogram_normalization not in ("matlab", "l1", "none"):
            raise ValueError("Unknown histogram_normalization.")
        if self.feature_order not in ("matlab", "branch-block-bin"):
            raise ValueError("Unknown feature_order.")
        for name in ("pca_image_batch_size", "pca_patch_chunk", "orientation_batch_size",
                     "gabor_tuning_batch_size", "response_batch_size"):
            if getattr(self, name) < 1:
                raise ValueError(f"{name} must be positive.")
        if self.num_workers < 0:
            raise ValueError("num_workers must be >= 0.")
        if self.max_patches_per_image is not None and self.max_patches_per_image < 1:
            raise ValueError("max_patches_per_image must be positive or None.")
        return self

    def to_dict(self):
        return asdict(self)

    def save(self, path):
        Path(path).write_text(json.dumps(self.to_dict(), indent=2), encoding="utf-8")

    @classmethod
    def load(cls, path):
        return cls(**json.loads(Path(path).read_text(encoding="utf-8"))).validate()
