"""Matching and evaluation, including ports of the supplied MATLAB helpers."""
from collections import Counter
import numpy as np
from scipy import sparse


def pairwise_distances(x, y=None, metric="euclidean", max_pairs=25_000_000):
    same_input = y is None
    x = sparse.csr_matrix(x, dtype=np.float64)
    y = x if same_input else sparse.csr_matrix(y, dtype=np.float64)
    if x.shape[1] != y.shape[1]:
        raise ValueError("Feature dimensions differ.")
    if x.shape[0] * y.shape[0] > max_pairs:
        raise ValueError("Distance matrix exceeds --max-pairs. Reduce the evaluation subset or explicitly raise the limit.")
    if not np.isfinite(x.data).all() or not np.isfinite(y.data).all():
        raise ValueError("Features contain NaN/Inf.")
    active = np.union1d(x.indices, y.indices)
    if len(active) < x.shape[1]:
        def compact(z):
            return sparse.csr_matrix((z.data, np.searchsorted(active, z.indices), z.indptr),
                                     shape=(z.shape[0], len(active)))
        x = compact(x)
        y = x if same_input else compact(y)
    result = np.empty((x.shape[0], y.shape[0]), dtype=np.float64)
    if metric == "euclidean":
        x2 = np.asarray(x.multiply(x).sum(axis=1)).ravel()
        y2 = np.asarray(y.multiply(y).sum(axis=1)).ravel()
        for start in range(0, len(x2), 64):
            cross = (x[start:start + 64] @ y.T).toarray()
            square = x2[start:start + len(cross), None] + y2[None] - 2 * cross
            # fastEuclideanDistance.m uses sqrt(abs(...)). abs reproduces tiny
            # negative roundoff handling more literally than clipping to zero.
            result[start:start + len(cross)] = np.sqrt(np.abs(square))
    elif metric == "chi2":
        if (x.data < 0).any() or (y.data < 0).any():
            raise ValueError("Chi-square distances require nonnegative histograms.")
        x.sort_indices(); y.sort_indices()
        eps = np.finfo(np.float64).eps
        for i in range(x.shape[0]):
            for j in range(y.shape[0]):
                # sc_pdist2.m: .5 * sum((x-y)^2/(x+y+eps)).
                # Sparse algebra over the union of non-zero bins gives the same value.
                delta = (x[i] - y[j]).tocsr(); summed = (x[i] + y[j]).tocsr()
                delta.eliminate_zeros(); delta.sort_indices(); summed.sort_indices()
                positions = np.searchsorted(summed.indices, delta.indices)
                result[i, j] = .5 * np.sum(delta.data ** 2 / (summed.data[positions] + eps))
    else:
        raise ValueError("metric must be euclidean or chi2.")
    return result


def verification(genuine, impostor):
    """Generic distance-based verification retained for non-MATLAB protocols."""
    genuine = np.sort(np.asarray(genuine, dtype=np.float64).ravel())
    impostor = np.sort(np.asarray(impostor, dtype=np.float64).ravel())
    if not len(genuine) or not len(impostor):
        raise ValueError("Verification needs at least one genuine and one impostor score.")
    if not np.isfinite(genuine).all() or not np.isfinite(impostor).all():
        raise ValueError("Verification scores contain NaN/Inf.")
    distinct = np.unique(np.concatenate([genuine, impostor]))
    thresholds = np.r_[np.nextafter(distinct[0], -np.inf), distinct]
    fmr = np.searchsorted(impostor, thresholds, side="right") / len(impostor)
    fnmr = 1 - np.searchsorted(genuine, thresholds, side="right") / len(genuine)
    gap = fmr - fnmr
    index = int(np.searchsorted(gap, 0))
    if index == 0:
        eer, eer_threshold = float((fmr[0] + fnmr[0]) / 2), float(thresholds[0])
    elif index >= len(gap):
        eer, eer_threshold = float((fmr[-1] + fnmr[-1]) / 2), float(thresholds[-1])
    elif gap[index] == 0:
        eer, eer_threshold = float(fmr[index]), float(thresholds[index])
    else:
        fraction = -gap[index - 1] / (gap[index] - gap[index - 1])
        eer = float(fmr[index - 1] + fraction * (fmr[index] - fmr[index - 1]))
        eer_threshold = float(thresholds[index - 1] + fraction * (thresholds[index] - thresholds[index - 1]))
    valid = np.flatnonzero(fmr <= .001)
    operating = int(valid[-1]) if len(valid) else 0
    metrics = {"eer": eer, "eer_threshold_interpolated": eer_threshold,
               "fnmr_at_fmr_0_001": float(fnmr[operating]), "achieved_fmr": float(fmr[operating]),
               "threshold_at_fmr_0_001": float(thresholds[operating]),
               "genuine_pairs": len(genuine), "impostor_pairs": len(impostor),
               "acceptance_rule": "distance <= threshold",
               "eer_method": "linear interpolation across empirical ROC crossing",
               "fmr1000_method": "FNMR at largest empirical threshold with FMR <= 0.001"}
    return metrics, {"thresholds": thresholds, "fmr": fmr, "fnmr": fnmr,
                     "genuine": genuine, "impostor": impostor}


def matlab_vl_roc(labels, scores):
    """Reproduce the TPR/TNR indexing documented for VLFeat vl_roc.

    TPR(k)/TNR(k) classify ranks <= k-1 as positive, hence element zero is
    the operating point before accepting any ranked sample.
    """
    labels = np.asarray(labels, dtype=np.int8).ravel()
    scores = np.asarray(scores, dtype=np.float64).ravel()
    if labels.shape != scores.shape or not len(labels):
        raise ValueError("labels and scores must be non-empty vectors of equal length.")
    keep = labels != 0
    labels, scores = labels[keep], scores[keep]
    if not np.isfinite(scores).all():
        raise ValueError("Scores contain NaN/Inf.")
    positives = int(np.sum(labels > 0)); negatives = int(np.sum(labels < 0))
    if positives == 0 or negatives == 0:
        raise ValueError("ROC needs positive and negative scores.")
    order = np.argsort(-scores, kind="stable")
    ranked = labels[order]
    pos = (ranked > 0).astype(np.int64)
    neg = (ranked < 0).astype(np.int64)
    tp_before = np.r_[0, np.cumsum(pos)[:-1]]
    fp_before = np.r_[0, np.cumsum(neg)[:-1]]
    tpr = tp_before / positives
    fpr = fp_before / negatives
    tnr = 1.0 - fpr
    fnr = 1.0 - tpr
    return tpr, tnr, fpr, fnr, order


def matlab_score_metrics(genuine_similarity, impostor_similarity):
    """Port indiciStatisticiIncertezzaVLFEAT + helper EER/FMR1000 logic."""
    genuine = np.asarray(genuine_similarity, dtype=np.float64).ravel()
    impostor = np.asarray(impostor_similarity, dtype=np.float64).ravel()
    if not len(genuine) or not len(impostor):
        raise ValueError("Verification needs at least one genuine and one impostor score.")
    labels = np.r_[np.ones(len(genuine), dtype=np.int8), -np.ones(len(impostor), dtype=np.int8)]
    scores = np.r_[genuine, impostor]
    all_scores_desc = np.sort(scores)[::-1]
    _, _, fpr, fnr, _ = matlab_vl_roc(labels, scores)
    diff = np.abs(fpr - fnr)
    eer_index = int(np.flatnonzero(diff == diff.min())[0])
    eer = float((fpr[eer_index] + fnr[eer_index]) / 2.0)
    valid = np.flatnonzero(fpr <= .001)
    if len(valid):
        # computeFMR1000.m takes the minimum FNMR in the valid prefix.
        local = int(np.argmin(fnr[valid]))
        fmr1000 = float(fnr[valid[local]])
        fmr_index = int(valid[local])
        threshold = float(all_scores_desc[fmr_index])
    else:
        fmr1000, fmr_index, threshold = 1.0, -1, float("nan")
    return {
        "eer": eer,
        "eer_index_matlab_1based": eer_index + 1,
        "eer_threshold": float(all_scores_desc[eer_index]),
        "fnmr_at_fmr_0_001": fmr1000,
        "fmr1000": fmr1000,
        "fmr1000_index_matlab_1based": fmr_index + 1 if fmr_index >= 0 else 0,
        "fmr1000_threshold": threshold,
        "genuine_pairs": int(len(genuine)),
        "impostor_pairs": int(len(impostor)),
        "acceptance_rule": "similarity >= threshold",
        "eer_method": "MATLAB computeEER_classic_minDiffFprFnr: min abs(FMR-FNMR), then mean",
        "fmr1000_method": "MATLAB computeFMR1000: minimum FNMR among FMR <= 0.001",
    }, {"fpr": fpr, "fnr": fnr, "scores_desc": all_scores_desc,
         "genuine_similarity": genuine, "impostor_similarity": impostor}


def matlab_movmax(values, k):
    """Port MATLAB movmax(A,k), including truncated endpoints."""
    values = np.asarray(values, dtype=np.float64).ravel()
    if k < 1:
        raise ValueError("Moving-window length must be >=1.")
    back = k // 2
    forward = k - back - 1
    out = np.empty_like(values)
    for i in range(len(values)):
        out[i] = np.max(values[max(0, i - back):min(len(values), i + forward + 1)])
    return out


def matlab_verification(distances, filename_labels, aggregate_k=4):
    """Port computeVerificationPerformance.m for the non-rotation case.

    The supplied MATLAB function loops over all ordered i,j pairs except the
    diagonal, converts distances to similarities via max(distance)+10-distance,
    then applies movmax separately to the genuine and impostor score vectors.
    """
    d = np.asarray(distances, dtype=np.float64)
    labels = np.asarray(filename_labels, dtype=str)
    if d.shape != (len(labels), len(labels)):
        raise ValueError("Distance matrix shape does not match labels.")
    genuine_dist, impostor_dist = [], []
    n = len(labels)
    for i in range(n):
        for j in range(n):
            if i == j:
                continue
            (genuine_dist if labels[i] == labels[j] else impostor_dist).append(float(d[i, j]))
    genuine_dist = np.asarray(genuine_dist, dtype=np.float64)
    impostor_dist = np.asarray(impostor_dist, dtype=np.float64)
    if not len(genuine_dist) or not len(impostor_dist):
        raise ValueError("MATLAB verification needs genuine and impostor comparisons.")
    maxgi = float(max(np.max(genuine_dist), np.max(impostor_dist)) + 10.0)
    genuine = maxgi - genuine_dist
    impostor = maxgi - impostor_dist
    normal, curves = matlab_score_metrics(genuine, impostor)
    aggr_genuine = matlab_movmax(genuine, aggregate_k)
    aggr_impostor = matlab_movmax(impostor, aggregate_k)
    aggregated, aggr_curves = matlab_score_metrics(aggr_genuine, aggr_impostor)
    normal["distance_to_similarity_offset"] = maxgi
    aggregated["distance_to_similarity_offset"] = maxgi
    aggregated["movmax_window"] = int(aggregate_k)
    curves.update({"genuine_distance": genuine_dist, "impostor_distance": impostor_dist})
    aggr_curves.update({"genuine_similarity_aggregated": aggr_genuine,
                        "impostor_similarity_aggregated": aggr_impostor})
    return normal, aggregated, curves, aggr_curves


def matlab_nearest_neighbor(distances, labels):
    """Port computekNNClassificationPerformance.m for k=1 and reused distances."""
    d = np.asarray(distances, dtype=np.float64)
    labels = np.asarray(labels, dtype=str)
    if d.shape != (len(labels), len(labels)):
        raise ValueError("Distance matrix shape does not match labels.")
    predictions = []
    for row in d:
        second_value = np.sort(row, kind="stable")[1]
        # MATLAB: idx=find(distV==minD); idx=idx(1)
        index = int(np.flatnonzero(row == second_value)[0])
        predictions.append(labels[index])
    return np.asarray(predictions)


def matlab_evaluate(distances, classification_labels, verification_labels=None, aggregate_k=4):
    labels = np.asarray(classification_labels, dtype=str)
    verify_labels = labels if verification_labels is None else np.asarray(verification_labels, dtype=str)
    normal, aggregated, curves, aggr_curves = matlab_verification(distances, verify_labels, aggregate_k)
    predicted = matlab_nearest_neighbor(distances, labels)
    unique = np.unique(labels)
    lookup = {label: i for i, label in enumerate(unique)}
    confusion = np.zeros((len(unique), len(unique)), dtype=np.int64)
    for actual, guess in zip(labels, predicted):
        confusion[lookup[actual], lookup[guess]] += 1
    normal.update({"accuracy": float(np.mean(predicted == labels)), "knn_neighbors": 1,
                   "identification": "MATLAB leave-one-out 1-NN on test set",
                   "test_images": len(labels), "reference_images": len(labels),
                   "confusion_labels": unique.tolist(), "confusion_matrix": confusion.tolist()})
    return normal, aggregated, curves, aggr_curves, predicted


def nearest_neighbors(distances, gallery_labels, k=1, exclude_self=False):
    labels = np.asarray(gallery_labels, dtype=str)
    d = np.asarray(distances, dtype=np.float64).copy()
    if exclude_self:
        if d.shape[0] != d.shape[1]:
            raise ValueError("Self exclusion requires a square distance matrix.")
        np.fill_diagonal(d, np.inf)
    if k < 1 or k > d.shape[1] - int(exclude_self):
        raise ValueError("Invalid number of nearest neighbors.")
    order = np.argsort(d, axis=1, kind="stable")[:, :k]
    predictions = []
    for indices in order:
        neighbors = labels[indices].tolist(); counts = Counter(neighbors); maximum = max(counts.values())
        predictions.append(next(label for label in neighbors if counts[label] == maximum))
    return np.asarray(predictions)


def evaluate(distances, probe_labels, gallery_labels=None, k=1):
    probes = np.asarray(probe_labels, dtype=str)
    leave_one_out = gallery_labels is None
    gallery = probes if leave_one_out else np.asarray(gallery_labels, dtype=str)
    if distances.shape != (len(probes), len(gallery)):
        raise ValueError("Distance shape does not match labels.")
    matching = probes[:, None] == gallery[None]
    if leave_one_out:
        i, j = np.triu_indices(len(probes), 1); scores, same = distances[i, j], matching[i, j]
    else:
        scores, same = distances.ravel(), matching.ravel()
    metrics, curves = verification(scores[same], scores[~same])
    predicted = nearest_neighbors(distances, gallery, k, leave_one_out)
    labels = np.unique(np.concatenate([probes, gallery])); lookup = {label: index for index, label in enumerate(labels)}
    confusion = np.zeros((len(labels), len(labels)), dtype=np.int64)
    for actual, guess in zip(probes, predicted): confusion[lookup[actual], lookup[guess]] += 1
    metrics.update({"accuracy": float(np.mean(predicted == probes)), "knn_neighbors": k,
                    "identification": "leave-one-out within held-out identities" if leave_one_out else "probe-to-training-gallery",
                    "test_images": len(probes), "reference_images": len(gallery),
                    "confusion_labels": labels.tolist(), "confusion_matrix": confusion.tolist()})
    return metrics, curves, predicted


def aggregate_verification(distances, probe_labels, gallery_labels=None, k=4, seed=0):
    """Optional non-MATLAB protocol retained for backwards compatibility."""
    probes = np.asarray(probe_labels, dtype=str)
    gallery = probes if gallery_labels is None else np.asarray(gallery_labels, dtype=str)
    rng = np.random.default_rng(seed); genuine, impostor = [], []; skipped = 0
    for i, actual in enumerate(probes):
        for claimed in np.unique(gallery):
            candidates = np.flatnonzero(gallery == claimed)
            if gallery_labels is None: candidates = candidates[candidates != i]
            if len(candidates) < k: skipped += 1; continue
            chosen = rng.choice(candidates, k, replace=False); score = float(np.mean(distances[i, chosen]))
            (genuine if actual == claimed else impostor).append(score)
    if not genuine or not impostor:
        return {"status": "insufficient_reference_samples", "k": k, "skipped_claims": skipped}, None
    metrics, curves = verification(genuine, impostor)
    metrics.update({"status": "ok", "k": k, "skipped_claims": skipped,
                    "protocol": "mean distance to k references sampled without replacement per probe/claimed identity; self excluded"})
    return metrics, curves
