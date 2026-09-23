"""Dataset discovery and protocols mirroring the supplied MATLAB common functions."""
from dataclasses import dataclass
from pathlib import Path
import csv
import re
import numpy as np

EXTENSIONS = {".bmp", ".png", ".jpg", ".jpeg", ".tif", ".tiff", ".pgm"}


@dataclass(frozen=True)
class Record:
    path: Path
    label: str
    split: str = ""


def matlab_identity_from_filename(filename):
    """Port of getIndName.m: concatenate all underscore fields except the last."""
    stem = Path(filename).stem
    parts = stem.split("_")
    if len(parts) < 2:
        raise ValueError(f"MATLAB getIndName convention needs an underscore: {Path(filename).name}")
    label = "".join(parts[:-1])
    if not label:
        raise ValueError(f"Could not infer MATLAB identity from {Path(filename).name}")
    return label


def discover(data_root=None, manifest=None, label_regex=None, require_labels=True):
    root = Path(data_root or ".").resolve()
    records = []
    if manifest:
        manifest = Path(manifest).resolve()
        base = root if data_root else manifest.parent
        with manifest.open(newline="", encoding="utf-8-sig") as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames or not {"path", "label"}.issubset(reader.fieldnames):
                raise ValueError("Manifest CSV must have path,label columns (optional: split).")
            for row in reader:
                path = Path(row["path"])
                path = (base / path).resolve() if not path.is_absolute() else path.resolve()
                records.append(Record(path, row["label"].strip(), row.get("split", "").strip().lower()))
    else:
        if not data_root or not root.is_dir():
            raise ValueError("Provide an existing --data-root or --manifest.")
        paths = [p for p in sorted(root.rglob("*")) if p.is_file() and p.suffix.lower() in EXTENSIONS]
        if not paths:
            raise ValueError("No images found.")
        regex = re.compile(label_regex) if label_regex else None
        flat = all(len(path.relative_to(root).parts) == 1 for path in paths)
        # The supplied MATLAB code uses getIndName(filename), i.e. all fields
        # before the final underscore. Automatically use that convention for
        # flat directories when every filename supports it.
        matlab_flat_labels = None
        if flat and regex is None and require_labels:
            try:
                matlab_flat_labels = {path: matlab_identity_from_filename(path.name) for path in paths}
            except ValueError:
                matlab_flat_labels = None
        for path in paths:
            relative = path.relative_to(root)
            if regex:
                match = regex.search(path.stem)
                if not match:
                    raise ValueError(f"Label regex does not match {path.name}.")
                if "label" in match.groupdict():
                    label = match.group("label")
                elif match.lastindex:
                    label = match.group(1)
                else:
                    raise ValueError("Label regex must contain a capture group, preferably (?P<label>...).")
            elif len(relative.parts) > 1:
                label = relative.parts[0]
            elif matlab_flat_labels is not None:
                label = matlab_flat_labels[path]
            elif require_labels:
                raise ValueError("Flat image directory does not follow the MATLAB underscore naming convention; specify --label-regex or a path,label CSV.")
            else:
                label = "unlabelled"
            records.append(Record(path.resolve(), label))
    if not records:
        raise ValueError("No images found.")
    paths = [record.path for record in records]
    if len(set(paths)) != len(paths):
        raise ValueError("Duplicate image paths in dataset/manifest.")
    for record in records:
        if not record.path.is_file():
            raise FileNotFoundError(record.path)
        if not record.label:
            raise ValueError(f"Missing label for {record.path}.")
        if record.split not in ("", "train", "test", "gallery", "probe"):
            raise ValueError(f"Unknown split {record.split!r} for {record.path}.")
    return records


def group_by_label(records):
    result = {}
    for record in records:
        result.setdefault(record.label, []).append(record)
    return result


def balance(records, min_samples=2, max_subjects=None, samples_per_subject=None, seed=0, matlab_order=False):
    """Filter/balance records.

    matlab_order=True mirrors balanceDB.m: retain identities in file order and
    retain the first N samples per identity. Otherwise sampling is random.
    """
    groups = group_by_label(records)
    required = max(min_samples, samples_per_subject or min_samples)
    eligible = {label for label, values in groups.items() if len(values) >= required}
    filtered = [r for r in records if r.label in eligible]
    if not filtered:
        raise ValueError("No identities meet the minimum sample requirement.")

    if matlab_order:
        labels = []
        for record in filtered:
            if record.label not in labels:
                labels.append(record.label)
        if max_subjects is not None:
            if len(labels) < max_subjects:
                raise ValueError(f"Requested {max_subjects} subjects but only {len(labels)} have >= {required} images.")
            labels = labels[:max_subjects]
        allowed = set(labels)
        counts = {label: 0 for label in labels}
        result = []
        for record in filtered:
            if record.label not in allowed:
                continue
            if samples_per_subject is None or counts[record.label] < samples_per_subject:
                result.append(record)
                counts[record.label] += 1
        return result

    rng = np.random.default_rng(seed)
    labels = sorted(eligible)
    if max_subjects is not None:
        if max_subjects > len(labels):
            raise ValueError(f"Requested {max_subjects} subjects but only {len(labels)} have >= {required} images.")
        labels = sorted(rng.choice(labels, max_subjects, replace=False).tolist())
    result = []
    for label in labels:
        values = groups[label]
        if samples_per_subject is not None:
            indices = sorted(rng.choice(len(values), samples_per_subject, replace=False))
            values = [values[index] for index in indices]
        result.extend(values)
    return result


def make_matlab_person_fold(records, kfold=2, seed=0):
    """Port the protocol of personFold.m + computeIndexesPersonFold.m.

    One random fold is assigned independently to every identity; fold 1 is
    testing and every other fold is training. MATLAB's original script does
    not seed its RNG. This port accepts a seed so runs can be reproduced.
    """
    if kfold < 2:
        raise ValueError("kfold must be >= 2.")
    labels = [r.label for r in records]
    unique = sorted(set(labels))
    rng = np.random.RandomState(seed)  # MT19937, close to MATLAB's classic twister family
    numeric = None
    try:
        numeric = [int(label) for label in unique]
        if any(value < 1 or str(value) != str(int(label)) for value, label in zip(numeric, unique)):
            numeric = None
    except ValueError:
        numeric = None
    if numeric is not None:
        # personFold.m creates foldPerPerson for 1:max(labels), including gaps.
        folds = rng.randint(1, kfold + 1, size=max(numeric))
        assignment = {label: int(folds[int(label) - 1]) for label in unique}
    else:
        folds = rng.randint(1, kfold + 1, size=len(unique))
        assignment = dict(zip(unique, map(int, folds)))
    train = [r for r in records if assignment[r.label] != 1]
    test = [r for r in records if assignment[r.label] == 1]
    if not train or not test:
        raise ValueError("MATLAB person-fold draw produced an empty train or test set; change --seed.")
    return train, test, assignment


def make_split(records, protocol="person-disjoint", train_fraction=.5, seed=0):
    if not 0 < train_fraction < 1:
        raise ValueError("train_fraction must be in (0,1).")
    rng = np.random.default_rng(seed)
    specified = [bool(record.split) for record in records]
    if any(specified):
        if not all(specified):
            raise ValueError("Manifest split column must be filled for every row, or omitted for all rows.")
        train = [r for r in records if r.split in ("train", "gallery")]
        test = [r for r in records if r.split in ("test", "probe")]
    else:
        groups = group_by_label(records)
        labels = sorted(groups)
        train, test = [], []
        if protocol == "person-disjoint":
            if len(labels) < 3:
                raise ValueError("Person-disjoint evaluation needs at least 3 identities (>=1 fit, >=2 test).")
            number = max(1, min(len(labels) - 2, int(len(labels) * train_fraction)))
            training_labels = set(rng.choice(labels, number, replace=False).tolist())
            train = [r for r in records if r.label in training_labels]
            test = [r for r in records if r.label not in training_labels]
        else:
            for label in labels:
                values = groups[label]
                if len(values) < 2:
                    raise ValueError(f"Identity {label} needs >=2 samples for gallery/probe splitting.")
                indices = rng.permutation(len(values))
                number = max(1, min(len(values) - 1, int(len(values) * train_fraction)))
                train.extend(values[int(i)] for i in indices[:number])
                test.extend(values[int(i)] for i in indices[number:])
    if not train or not test:
        raise ValueError("The split must contain both training and testing images.")
    train_ids, test_ids = {r.label for r in train}, {r.label for r in test}
    if protocol == "person-disjoint":
        if train_ids & test_ids:
            raise ValueError("Person-disjoint protocol requires no identity overlap between fit and test.")
        if len(test_ids) < 2 or any(len(v) < 2 for v in group_by_label(test).values()):
            raise ValueError("Test split needs >=2 identities and >=2 images per identity for verification and leave-one-out identification.")
    elif protocol == "gallery-probe":
        if not test_ids.issubset(train_ids) or len(train_ids) < 2:
            raise ValueError("Gallery/probe evaluation needs >=2 gallery identities and every probe identity in the gallery.")
    else:
        raise ValueError("Unknown evaluation protocol.")
    return train, test


def write_manifest(path, records):
    with Path(path).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["path", "label", "split"])
        writer.writerows((str(r.path), r.label, r.split) for r in records)
