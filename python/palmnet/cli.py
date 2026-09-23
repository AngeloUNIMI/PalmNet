"""Windows/Linux command-line runner."""
import argparse
import csv
import json
import logging
from pathlib import Path
import sys
import time
from dataclasses import replace
import numpy as np
from PIL import Image
from scipy import sparse
import torch
from .config import PalmConfig
from .data import Record, balance, discover, make_matlab_person_fold, make_split, write_manifest
from .evaluation import aggregate_verification, evaluate, matlab_evaluate, pairwise_distances
from .model import PalmPCAGabor

LOG = logging.getLogger(__name__)


def _json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False), encoding="utf-8")


def _data_args(parser):
    parser.add_argument("--data-root", type=Path)
    parser.add_argument("--manifest", type=Path, help="CSV path,label[,split]; relative paths use data-root or CSV directory")
    parser.add_argument("--label-regex", help="Filename stem regex; named 'label' group or first capture is the identity")


def _model_args(parser):
    parser.add_argument("--config", type=Path)
    parser.add_argument("--image-size", type=int)
    parser.add_argument("--pca-patch-size", type=int)
    parser.add_argument("--pca-filters", type=int)
    parser.add_argument("--retained-variance", type=float)
    parser.add_argument("--fixed-orientations", type=int)
    parser.add_argument("--adaptive-orientations", type=int)
    parser.add_argument("--selected-wavelets", type=int)
    parser.add_argument("--num-wavelet-responses", type=int)
    parser.add_argument("--hist-block-size", type=int, nargs=2)
    parser.add_argument("--block-overlap", type=float)
    parser.add_argument("--orientation-histogram", choices=["legacy-range", "fixed"])
    parser.add_argument("--dtype", choices=["float32", "float64"], help="Low-level response dtype; --precision is the friendlier preset")
    parser.add_argument("--precision", choices=["matlab", "fast"], help="matlab=float64 responses; fast=float32 responses; PCA covariance/eigh stays float64")
    parser.add_argument("--execution-backend", choices=["auto", "reference", "optimized"], help="auto uses optimized batching on CUDA and reference mode on CPU")
    parser.add_argument("--convolution-backend", choices=["auto", "direct", "fft"])
    parser.add_argument("--max-patches-per-image", type=int)
    parser.add_argument("--pca-image-batch-size", type=int)
    parser.add_argument("--pca-patch-chunk", type=int)
    parser.add_argument("--orientation-batch-size", type=int)
    parser.add_argument("--gabor-tuning-batch-size", type=int)
    parser.add_argument("--response-batch-size", type=int)


def _runtime_args(parser):
    parser.add_argument("--device", default="auto", help="auto, cpu, cuda, cuda:0, ...")
    parser.add_argument("--batch-size", type=int, default=8, help="Images per feature-extraction batch")
    parser.add_argument("--num-workers", type=int, default=0, help="Parallel image-decoding workers; try 2-4 on Windows")
    parser.add_argument("--pin-memory", action=argparse.BooleanOptionalAction, default=True, help="Enable pinned-memory DataLoader transfers when applicable")
    parser.add_argument("--compile", action="store_true", help="Use torch.compile for supported dense convolution stages")
    parser.add_argument("--threads", type=int, default=4, help="PyTorch CPU threads; avoid excessive oversubscription")
    parser.add_argument("--seed", type=int, default=0)


def _config(args):
    config = PalmConfig.load(args.config) if args.config else PalmConfig()
    mappings = {"fixed_orientations": "default_orientations"}
    for name in ("image_size", "pca_patch_size", "pca_filters", "retained_variance", "fixed_orientations",
                 "adaptive_orientations", "selected_wavelets", "num_wavelet_responses", "hist_block_size",
                 "block_overlap", "orientation_histogram", "dtype", "execution_backend", "convolution_backend",
                 "max_patches_per_image", "pca_image_batch_size", "pca_patch_chunk",
                 "orientation_batch_size", "gabor_tuning_batch_size", "response_batch_size"):
        value = getattr(args, name, None)
        if value is not None:
            setattr(config, mappings.get(name, name), value)
    precision = getattr(args, "precision", None)
    if precision is not None:
        if getattr(args, "dtype", None) is not None:
            raise ValueError("Use either --precision or --dtype, not both.")
        config.dtype = "float64" if precision == "matlab" else "float32"
    config.compile_dense = bool(getattr(args, "compile", False))
    config.num_workers = int(getattr(args, "num_workers", config.num_workers))
    config.pin_memory = bool(getattr(args, "pin_memory", config.pin_memory))
    config.seed = args.seed
    return config.validate()


def build_parser():
    parser = argparse.ArgumentParser(description="PCA-Gabor PalmNet: conversion of the supplied June 2018 MATLAB pipeline")
    sub = parser.add_subparsers(dest="command", required=True)
    experiment = sub.add_parser("experiment", help="Fit and evaluate repeated, explicitly defined splits")
    _data_args(experiment)
    _model_args(experiment)
    _runtime_args(experiment)
    experiment.add_argument("--output", type=Path, default=Path("results/pca_gabor"))
    experiment.add_argument("--iterations", type=int, default=5)
    experiment.add_argument("--protocol", choices=["matlab", "person-disjoint", "gallery-probe"], default="matlab",
                            help="matlab reproduces personFold.m + MATLAB test-set evaluation")
    experiment.add_argument("--train-fraction", type=float, default=.5, help="Used only by non-MATLAB protocols")
    experiment.add_argument("--kfold", type=int, default=2, help="MATLAB personFold.m fold count; fold 1 is test")
    experiment.add_argument("--num-score-aggregate", type=int, default=4, help="MATLAB movmax score aggregation window")
    experiment.add_argument("--matlab-balance", action="store_true", help="Mirror balanceDB.m ordering when max-subjects/samples-per-subject are set")
    experiment.add_argument("--neighbors", type=int, default=1)
    experiment.add_argument("--distance", choices=["euclidean", "chi2"], default="euclidean")
    experiment.add_argument("--max-subjects", type=int)
    experiment.add_argument("--samples-per-subject", type=int)
    experiment.add_argument("--aggregate-k", type=int, default=0, help="Optional NEW mean-of-k reference protocol; 0 disables")
    experiment.add_argument("--max-pairs", type=int, default=25_000_000)
    experiment.add_argument("--no-save-features", action="store_true")
    experiment.add_argument("--overwrite", action="store_true", help="Permit replacing result files in an existing output directory")
    train = sub.add_parser("train", help="Fit unsupervised filters on the supplied images and save a checkpoint")
    _data_args(train)
    _model_args(train)
    _runtime_args(train)
    train.add_argument("--checkpoint", type=Path, required=True)
    extract = sub.add_parser("extract", help="Extract features using an existing checkpoint")
    _data_args(extract)
    _runtime_args(extract)
    extract.add_argument("--checkpoint", type=Path, required=True)
    extract.add_argument("--output", type=Path, default=Path("features.npz"))
    demo = sub.add_parser("demo", help="Generate toy ridge images and run a reduced end-to-end smoke test")
    _runtime_args(demo)
    demo.add_argument("--output", type=Path, default=Path("demo_results"))
    demo.add_argument("--overwrite", action="store_true")
    return parser


def _experiment(args, config):
    if args.iterations < 1 or args.aggregate_k < 0 or args.num_score_aggregate < 1 or args.kfold < 2:
        raise ValueError("iterations >=1, aggregate-k >=0, num-score-aggregate >=1, and kfold >=2 are required.")
    if args.output.exists() and any(args.output.iterdir()) and not args.overwrite:
        raise FileExistsError(f"Output directory is not empty: {args.output}. Choose another directory or use --overwrite.")
    args.output.mkdir(parents=True, exist_ok=True)
    handler = logging.FileHandler(args.output / "run.log", mode="w", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logging.getLogger().addHandler(handler)
    try:
        records = discover(args.data_root, args.manifest, args.label_regex)
        if any(r.split for r in records):
            if args.max_subjects is not None or args.samples_per_subject is not None:
                raise ValueError("Do not combine explicit manifest splits with automatic balancing.")
            if args.iterations != 1:
                raise ValueError("An explicit manifest split describes one run; set --iterations 1.")
        else:
            records = balance(records, max_subjects=args.max_subjects, samples_per_subject=args.samples_per_subject, seed=args.seed,
                              matlab_order=(args.protocol == "matlab" and args.matlab_balance))
        config.save(args.output / "config.json")
        _json(args.output / "arguments.json", {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()})
        _json(args.output / "environment.json", {"python": sys.version, "torch": torch.__version__, "numpy": np.__version__,
                                                  "cuda_available": torch.cuda.is_available(), "requested_device": args.device})
        if args.protocol == "matlab":
            LOG.info("Using supplied MATLAB common-function protocol: getIndName/personFold/verification/1-NN semantics.")
        else:
            LOG.info("Using explicit non-MATLAB evaluation protocol: %s", args.protocol)
        results = []
        for iteration in range(args.iterations):
            start = time.perf_counter()
            seed = args.seed + iteration
            if args.protocol == "matlab" and not any(r.split for r in records):
                train, test, fold_assignment = make_matlab_person_fold(records, args.kfold, seed)
                _json(args.output / f"fold_assignment_{iteration + 1:03d}.json", fold_assignment)
            else:
                split_protocol = "person-disjoint" if args.protocol == "matlab" else args.protocol
                train, test = make_split(records, split_protocol, args.train_fraction, seed)
            output = args.output / f"iteration_{iteration + 1:03d}"
            output.mkdir(parents=True, exist_ok=True)
            LOG.info("Iteration %d/%d: fit=%d images/%d identities, test=%d images/%d identities", iteration + 1, args.iterations,
                     len(train), len({r.label for r in train}), len(test), len({r.label for r in test}))
            split_records = [Record(r.path, r.label, "train") for r in train] + [Record(r.path, r.label, "test") for r in test]
            write_manifest(output / "split.csv", split_records)
            model = PalmPCAGabor(replace(config, seed=seed), args.device).fit([r.path for r in train])
            model.save(output / "model.pt")
            _json(output / "fit_info.json", model.fit_info)
            probe_features = model.transform([r.path for r in test], args.batch_size)
            if not args.no_save_features:
                sparse.save_npz(output / "test_features.npz", probe_features)
            gallery_labels = None
            if args.protocol == "gallery-probe":
                gallery_features = model.transform([r.path for r in train], args.batch_size)
                distances = pairwise_distances(probe_features, gallery_features, args.distance, args.max_pairs)
                gallery_labels = [r.label for r in train]
                if not args.no_save_features:
                    sparse.save_npz(output / "gallery_features.npz", gallery_features)
            else:
                distances = pairwise_distances(probe_features, metric=args.distance, max_pairs=args.max_pairs)
                np.fill_diagonal(distances, 0)
            labels = [r.label for r in test]
            if args.protocol == "matlab":
                if gallery_labels is not None:
                    raise ValueError("MATLAB protocol evaluates only within the held-out test set.")
                verification_labels = [r.path.name[:4] for r in test]  # computeVerificationPerformance.m
                metrics, matlab_aggregated, curves, aggregate_curves, predicted = matlab_evaluate(
                    distances, labels, verification_labels, args.num_score_aggregate)
                metrics["matlab_aggregated_verification"] = matlab_aggregated
                np.savez_compressed(output / "aggregate_curves.npz", **aggregate_curves)
            else:
                metrics, curves, predicted = evaluate(distances, labels, gallery_labels, args.neighbors)
                if args.aggregate_k:
                    aggregate, aggregate_curves = aggregate_verification(distances, labels, gallery_labels, args.aggregate_k, seed)
                    metrics["aggregate_verification_new_protocol"] = aggregate
                    if aggregate_curves is not None:
                        np.savez_compressed(output / "aggregate_curves.npz", **aggregate_curves)
            metrics.update({"iteration": iteration + 1, "seed": seed, "protocol": args.protocol, "distance": args.distance,
                            "feature_dimension": model.feature_dimension, "pca_filters": model.num_pca_filters,
                            "gabor_filters": model.num_gabor_filters, "elapsed_seconds": time.perf_counter() - start})
            _json(output / "metrics.json", metrics)
            np.savez_compressed(output / "verification_curves.npz", **curves)
            np.save(output / "distances.npy", distances)
            with (output / "predictions.csv").open("w", newline="", encoding="utf-8") as handle:
                writer = csv.writer(handle)
                writer.writerow(["path", "true_label", "predicted_label"])
                writer.writerows((str(r.path), r.label, guess) for r, guess in zip(test, predicted))
            results.append(metrics)
            LOG.info("Iteration %d: accuracy=%.4f%% EER=%.4f%% FMR1000=%.4f%%", iteration + 1,
                     100 * metrics["accuracy"], 100 * metrics["eer"], 100 * metrics["fnmr_at_fmr_0_001"])
            if args.protocol == "matlab":
                ma = metrics["matlab_aggregated_verification"]
                LOG.info("Iteration %d: aggregated(%d) EER=%.4f%% FMR1000=%.4f%%", iteration + 1,
                         args.num_score_aggregate, 100 * ma["eer"], 100 * ma["fmr1000"])
        summary = {"protocol": args.protocol, "iterations": len(results), "units": "fractions; multiply by 100 for percentages",
                   "std_definition": "sample standard deviation (ddof=1); zero for one run",
                   "matlab_common_functions": "ported from supplied archive" if args.protocol == "matlab" else "not used",
                   "runs": results}
        for name in ("accuracy", "eer", "fnmr_at_fmr_0_001"):
            values = [result[name] for result in results]
            summary[name + "_mean"] = float(np.mean(values))
            summary[name + "_std"] = float(np.std(values, ddof=1)) if len(values) > 1 else 0.0
        if args.protocol == "matlab":
            for name in ("eer", "fmr1000"):
                values = [result["matlab_aggregated_verification"][name] for result in results]
                summary["aggregated_" + name + "_mean"] = float(np.mean(values))
                summary["aggregated_" + name + "_std"] = float(np.std(values, ddof=1)) if len(values) > 1 else 0.0
        _json(args.output / "summary.json", summary)
        LOG.info("Results saved to %s", args.output.resolve())
        return summary
    finally:
        logging.getLogger().removeHandler(handler)
        handler.close()


def _demo(args):
    if args.output.exists() and any(args.output.iterdir()) and not args.overwrite:
        raise FileExistsError("Demo output directory is not empty. Choose a new directory or add --overwrite.")
    rng = np.random.default_rng(args.seed)
    data = args.output / "toy_images"
    y, x = np.mgrid[:32, :32]
    for subject in range(6):
        folder = data / f"subject_{subject:02d}"
        folder.mkdir(parents=True, exist_ok=True)
        angle = np.pi * subject / 6
        ridge = np.cos(angle) * x + np.sin(angle) * y
        for sample in range(4):
            image = 127 + 55 * np.cos((.45 + subject * .025) * ridge + sample * .05)
            image += 20 * np.cos(.2 * (x - y) + subject) + rng.normal(0, 4, (32, 32))
            Image.fromarray(np.clip(image, 0, 255).astype(np.uint8)).save(folder / f"sample_{sample:02d}.png")
    config = PalmConfig(image_size=32, pca_patch_size=5, pca_filters=3, default_orientations=4,
                        adaptive_orientations=3, selected_wavelets=2, hist_block_size=(8, 8),
                        num_wavelet_responses=100, fixed_half_size=7, orientation_histogram="fixed", seed=args.seed)
    experiment_args = argparse.Namespace(**vars(args))
    experiment_args.output = args.output / "experiment"
    experiment_args.data_root = data
    experiment_args.manifest = experiment_args.label_regex = None
    experiment_args.max_subjects = experiment_args.samples_per_subject = None
    experiment_args.iterations = 1
    experiment_args.protocol = "person-disjoint"
    experiment_args.train_fraction = .5
    experiment_args.kfold = 2
    experiment_args.num_score_aggregate = 4
    experiment_args.matlab_balance = False
    experiment_args.neighbors = 1
    experiment_args.distance = "euclidean"
    experiment_args.max_pairs = 25_000_000
    experiment_args.no_save_features = False
    experiment_args.aggregate_k = 0
    LOG.warning("Toy smoke test only: synthetic results are NOT palmprint benchmark results.")
    return _experiment(experiment_args, config)


def main(argv=None):
    args = build_parser().parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        if args.threads < 1 or args.batch_size < 1 or args.num_workers < 0:
            raise ValueError("--threads/--batch-size must be positive and --num-workers must be >= 0.")
        torch.set_num_threads(args.threads)
        torch.manual_seed(args.seed)
        np.random.seed(args.seed)
        if torch.cuda.is_available():
            torch.backends.cuda.matmul.allow_tf32 = False
            torch.backends.cudnn.allow_tf32 = False
            torch.backends.cudnn.benchmark = False
            torch.backends.cudnn.deterministic = True
        if args.command == "demo":
            _demo(args)
        elif args.command == "experiment":
            _experiment(args, _config(args))
        elif args.command == "train":
            records = discover(args.data_root, args.manifest, args.label_regex, require_labels=False)
            if any(r.split for r in records):
                if not all(r.split for r in records):
                    raise ValueError("Partially specified manifest split column.")
                records = [r for r in records if r.split in ("train", "gallery")]
                if not records:
                    raise ValueError("Manifest contains no training/gallery records.")
            model = PalmPCAGabor(_config(args), args.device).fit([r.path for r in records])
            model.save(args.checkpoint)
            _json(args.checkpoint.with_suffix(".fit_info.json"), model.fit_info)
            LOG.info("Checkpoint saved: %s", args.checkpoint.resolve())
        elif args.command == "extract":
            model = PalmPCAGabor.load(args.checkpoint, args.device)
            model.config.num_workers = args.num_workers
            model.config.pin_memory = args.pin_memory
            if args.compile:
                model.enable_compile()
            records = discover(args.data_root, args.manifest, args.label_regex, require_labels=False)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            if args.output.suffix.lower() != ".npz":
                raise ValueError("--output must end in .npz for sparse features.")
            features = model.transform([r.path for r in records], args.batch_size)
            sparse.save_npz(args.output, features)
            write_manifest(args.output.with_suffix(".csv"), records)
            LOG.info("Saved sparse features: shape=%s, nnz=%d, file=%s", features.shape, features.nnz, args.output)
        return 0
    except (ValueError, FileNotFoundError, FileExistsError, RuntimeError) as error:
        LOG.error("%s", error)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
