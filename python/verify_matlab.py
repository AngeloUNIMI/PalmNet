"""Compare an actual MATLAB-exported fixture with the imported PyTorch model."""
import argparse
import json
import sys
import numpy as np
from scipy import sparse
from scipy.io import loadmat
import torch
from palmnet import PalmPCAGabor
from palmnet.ops import ridge_orientation


def error_report(actual, expected, atol, rtol):
    expected = np.asarray(expected)
    if actual.shape != expected.shape:
        return {"pass": False, "actual_shape": list(actual.shape), "expected_shape": list(expected.shape)}
    delta = np.abs(actual - expected)
    return {"pass": bool(np.allclose(actual, expected, atol=atol, rtol=rtol)),
            "max_absolute_error": float(delta.max(initial=0)),
            "max_error_scaled_by_reference_max": float(delta.max(initial=0) / max(float(np.abs(expected).max(initial=0)), np.finfo(float).tiny))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture")
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--backend", choices=["direct", "fft", "auto"], default="direct")
    parser.add_argument("--atol", type=float, default=1e-7)
    parser.add_argument("--rtol", type=float, default=1e-8)
    parser.add_argument("--save-model")
    args = parser.parse_args()
    torch.set_num_threads(2)
    data = loadmat(args.fixture)
    required = {"input_image", "pca_vectors", "gabor_kernels", "pca_output", "gabor_output", "hash_codes", "features"}
    missing = required - set(data)
    if missing:
        raise ValueError(f"Fixture is missing: {sorted(missing)}. Use matlab/export_pytorch_fixture.m.")
    model = PalmPCAGabor.from_matlab_fixture(args.fixture, args.device)
    model.config.convolution_backend = args.backend
    x = torch.as_tensor(data["input_image"], device=model.device, dtype=model.dtype)[None, None]
    first, second = model.intermediate_responses(x)
    first = first[0].permute(1, 2, 0).cpu().numpy()
    second = second[0].permute(2, 3, 0, 1).reshape(model.image_size, model.image_size, -1).cpu().numpy()
    codes = model.hash_codes(x)[0].permute(1, 2, 0).cpu().numpy()
    expected_first = data["pca_output"]
    expected_codes = data["hash_codes"]
    if expected_first.ndim == 2:
        expected_first = expected_first[..., None]
    if expected_codes.ndim == 2:
        expected_codes = expected_codes[..., None]
    expected_second = data["gabor_output"]
    if expected_second.ndim == 2:
        expected_second = expected_second[..., None]
    report = {"pca_responses": error_report(first, expected_first, args.atol, args.rtol),
              "gabor_responses": error_report(second, expected_second, args.atol, args.rtol),
              "hash_codes": {"pass": bool(np.array_equal(codes, expected_codes)),
                             "mismatched_pixels": int(np.count_nonzero(codes != expected_codes))}}
    output = model(x).coalesce().cpu()
    indices = output.indices().numpy()
    actual = sparse.csr_matrix((output.values().numpy(), (indices[0], indices[1])), shape=output.shape)
    reference = sparse.csr_matrix(data["features"]).T.tocsr()
    if actual.shape != reference.shape:
        report["features"] = {"pass": False, "actual_shape": actual.shape, "expected_shape": reference.shape}
    else:
        delta = actual - reference
        delta.eliminate_zeros()
        maximum = float(np.max(np.abs(delta.data), initial=0))
        report["features"] = {"pass": maximum <= args.atol, "max_absolute_error": maximum,
                              "different_feature_entries": delta.nnz, "feature_dimension": actual.shape[1]}
    if "orientation_radians" in data:
        orientation = ridge_orientation(x)[0, 0].cpu().numpy()
        report["orientation"] = error_report(orientation, data["orientation_radians"], args.atol, args.rtol)
    print(json.dumps(report, indent=2))
    if args.save_model:
        model.save(args.save_model)
    success = all(result["pass"] for result in report.values())
    if not success:
        print("Parity check failed. Inspect response alignment and near-zero sign differences before comparing benchmark scores.", file=sys.stderr)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
