#!/usr/bin/env python3
"""
PROBE-2 reference 01 — sklearn DecisionTreeClassifier on a 4-feature
6-class numeric tabular CSV (synthesized iris-shaped subset, hand-frozen
so the script is fully self-contained and reproducible without any
external data dependency).

Reference versions used to generate the committed JSON:
    Python 3.11.9
    numpy 2.2.6
    scikit-learn 1.8.0

Pipeline:
    1. Load 12-row CSV (4 features, 1 integer target).
    2. Train/test split (test_size=4 of 12 = 1/3, random_state=42, stratify=None).
    3. Fit DecisionTreeClassifier(random_state=42) on the 8-row train subset.
    4. Predict on the 4-row holdout.
    5. Emit predictions + accuracy + class IDs as JSON.

Re-run to regenerate:
    python tests/reference/ml/01_tabular_classification.py > \\
        tests/reference/ml/01_tabular_classification.json

The Nucleor-side probe (pipeline_01_tabular_classification.nr, future
ml-probe-2-pipeline-parity-v0846) must produce JSON byte-equal to the
committed expected file within parity-manifest tolerance.
"""

import io
import json
import sys

import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score


CSV_TEXT = """sepal_length,sepal_width,petal_length,petal_width,species
5.1,3.5,1.4,0.2,0
4.9,3.0,1.4,0.2,0
4.7,3.2,1.3,0.2,0
4.6,3.1,1.5,0.2,0
7.0,3.2,4.7,1.4,1
6.4,3.2,4.5,1.5,1
6.9,3.1,4.9,1.5,1
5.5,2.3,4.0,1.3,1
6.3,3.3,6.0,2.5,2
5.8,2.7,5.1,1.9,2
7.1,3.0,5.9,2.1,2
6.3,2.9,5.6,1.8,2
"""


def main() -> None:
    raw = np.loadtxt(io.StringIO(CSV_TEXT), delimiter=",", skiprows=1, dtype=np.float64)
    x = raw[:, 0:4]
    y = raw[:, 4].astype(np.int64)

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=4, random_state=42, shuffle=True
    )

    clf = DecisionTreeClassifier(random_state=42)
    clf.fit(x_train, y_train)
    y_pred = clf.predict(x_test).astype(np.int64)
    acc = float(accuracy_score(y_test, y_pred))

    result = {
        "case": "01_tabular_classification",
        "model": "sklearn.tree.DecisionTreeClassifier",
        "random_state": 42,
        "n_train": int(x_train.shape[0]),
        "n_test": int(x_test.shape[0]),
        "n_features": int(x.shape[1]),
        "classes": [int(c) for c in clf.classes_],
        "y_test": [int(v) for v in y_test],
        "y_pred": [int(v) for v in y_pred],
        "accuracy": acc,
        "tolerance_abs": 1e-09,
    }
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
