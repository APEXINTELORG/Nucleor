#!/usr/bin/env python3
"""
PROBE-2 reference 04 — sklearn BernoulliNB on a small text classification
corpus (12 short documents, 2 classes). The vocabulary is hand-frozen
into a binary bag-of-words feature matrix so the script is fully
self-contained — no CountVectorizer / external corpus / file IO needed.

Reference versions used to generate the committed JSON:
    Python 3.11.9
    numpy 2.2.6
    scikit-learn 1.8.0

Pipeline:
    1. Load 12-row binary BoW CSV (8 vocabulary features + 1 class label).
    2. Train/test split (test_size=4 of 12, random_state=42, shuffle=True).
    3. Fit BernoulliNB(alpha=1.0) on the 8-row train subset.
    4. Predict on the 4-row holdout.
    5. Emit predictions + accuracy + class log-priors as JSON.

Re-run to regenerate:
    python tests/reference/ml/04_text_classification.py > \\
        tests/reference/ml/04_text_classification.json

The Nucleor-side probe (pipeline_04_text_classification.nr) must produce
JSON byte-equal to this committed reference within parity-manifest
tolerance.

Vocabulary (column order):
  v0 = "good"     v1 = "great"   v2 = "excellent"  v3 = "wonderful"
  v4 = "bad"      v5 = "terrible" v6 = "awful"      v7 = "horrible"

Class 0 = positive (top vocab present), class 1 = negative (bottom vocab).
"""

import io
import json
import sys

import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import BernoulliNB
from sklearn.metrics import accuracy_score


CSV_TEXT = """v0,v1,v2,v3,v4,v5,v6,v7,label
1,1,0,0,0,0,0,0,0
1,0,1,0,0,0,0,0,0
0,1,1,1,0,0,0,0,0
1,1,1,0,0,0,0,0,0
0,0,1,1,0,0,0,0,0
1,0,0,1,0,0,0,0,0
0,0,0,0,1,1,0,0,1
0,0,0,0,1,0,1,0,1
0,0,0,0,0,1,1,1,1
0,0,0,0,1,1,1,0,1
0,0,0,0,0,0,1,1,1
0,0,0,0,1,0,0,1,1
"""


def main() -> None:
    raw = np.loadtxt(io.StringIO(CSV_TEXT), delimiter=",", skiprows=1, dtype=np.int64)
    x = raw[:, 0:8].astype(np.float64)
    y = raw[:, 8].astype(np.int64)

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=4, random_state=42, shuffle=True
    )

    nb = BernoulliNB(alpha=1.0)
    nb.fit(x_train, y_train)
    y_pred = nb.predict(x_test).astype(np.int64)
    acc = float(accuracy_score(y_test, y_pred))

    # Per ml_agent_probe2_design_no_fit_apis_v0846_2026-05-08.md:
    # Nucleor has no BernoulliNB fit API. Dump fitted feature_log_prob
    # + class_log_prior + classes so the Nucleor probe can run
    # predict-only (joint log-likelihood + argmax).
    params = {
        "feature_log_prob": [[float(v) for v in row] for row in nb.feature_log_prob_],
        "class_log_prior": [float(v) for v in nb.class_log_prior_],
        "classes": [int(c) for c in nb.classes_],
    }
    holdout = {
        "x_test": [[int(v) for v in row] for row in x_test.astype(np.int64)],
    }

    result = {
        "case": "04_text_classification",
        "model": "sklearn.naive_bayes.BernoulliNB",
        "alpha": 1.0,
        "random_state": 42,
        "n_train": int(x_train.shape[0]),
        "n_test": int(x_test.shape[0]),
        "n_features": int(x.shape[1]),
        "classes": [int(c) for c in nb.classes_],
        "class_log_prior": [float(v) for v in nb.class_log_prior_],
        "y_test": [int(v) for v in y_test],
        "y_pred": [int(v) for v in y_pred],
        "accuracy": acc,
        "params": params,
        "holdout": holdout,
        "tolerance_abs": 1e-09,
    }
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
