#!/usr/bin/env python3
"""
PROBE-2 reference 03 — sklearn KMeans on a 15-row 2-feature synthetic
CSV (3 distinct clusters, hand-frozen for reproducibility without any
external data dependency).

Reference versions used to generate the committed JSON:
    Python 3.11.9
    numpy 2.2.6
    scikit-learn 1.8.0

Pipeline:
    1. Load 15-row CSV (2 features, no target).
    2. Fit KMeans(n_clusters=3, n_init=10, random_state=42).
    3. Emit centroids + cluster labels + inertia as JSON.

Re-run to regenerate:
    python tests/reference/ml/03_clustering.py > \\
        tests/reference/ml/03_clustering.json

The Nucleor-side probe (pipeline_03_clustering.nr) must produce JSON
byte-equal to this committed reference within parity-manifest tolerance.
"""

import io
import json
import sys

import numpy as np
from sklearn.cluster import KMeans


# 3 visually distinct clusters around (1,1), (10,10), (1,10).
CSV_TEXT = """x1,x2
1.0,1.2
1.2,0.9
0.8,1.1
1.1,1.0
1.0,0.8
10.0,10.2
10.2,9.9
9.8,10.1
10.1,10.0
10.0,9.8
1.0,10.2
1.2,9.9
0.8,10.1
1.1,10.0
1.0,9.8
"""


def main() -> None:
    raw = np.loadtxt(io.StringIO(CSV_TEXT), delimiter=",", skiprows=1, dtype=np.float64)
    x = raw

    km = KMeans(n_clusters=3, n_init=10, random_state=42)
    km.fit(x)
    labels = km.labels_.astype(np.int64)
    centers = km.cluster_centers_
    inertia = float(km.inertia_)

    # Per ml_agent_probe2_design_no_fit_apis_v0846_2026-05-08.md:
    # Nucleor has no KMeans fit API. Dump fitted centers so the Nucleor
    # probe can run kmeans_f64_predict only (predict reproduces labels
    # byte-equal once the centers match). Note: KMeans labels are
    # permutation-invariant — the cluster IDs are arbitrary; the parity
    # check accepts any permutation that produces the same cluster
    # assignment partition.
    params = {
        "centers": [[float(v) for v in row] for row in centers],
    }
    holdout = {
        "x": [[float(v) for v in row] for row in x],
    }

    result = {
        "case": "03_clustering",
        "model": "sklearn.cluster.KMeans",
        "random_state": 42,
        "n_clusters": 3,
        "n_init": 10,
        "n_samples": int(x.shape[0]),
        "n_features": int(x.shape[1]),
        "labels": [int(v) for v in labels],
        "centers": [[float(v) for v in row] for row in centers],
        "inertia": inertia,
        "params": params,
        "holdout": holdout,
        "tolerance_abs": 1e-09,
    }
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
