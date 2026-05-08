#!/usr/bin/env python3
"""
PROBE-2 reference 02 — sklearn LinearRegression on a 12-row 3-feature
synthetic CSV (hand-frozen so the script is fully self-contained and
reproducible without any external data dependency).

Reference versions used to generate the committed JSON:
    Python 3.11.9
    numpy 2.2.6
    scikit-learn 1.8.0

Pipeline:
    1. Load 12-row CSV (3 features, 1 continuous target).
    2. Train/test split (test_size=4 of 12 = 1/3, random_state=42, shuffle=True).
    3. Fit LinearRegression() on the 8-row train subset.
    4. Predict on the 4-row holdout.
    5. Emit predictions + R2 score + coef + intercept as JSON.

Re-run to regenerate:
    python tests/reference/ml/02_regression.py > \\
        tests/reference/ml/02_regression.json

The Nucleor-side probe (pipeline_02_regression.nr, future
ml-probe-2-pipeline-parity-v0846 .nr layer) must produce JSON byte-equal
to this committed reference within parity-manifest tolerance.
"""

import io
import json
import sys

import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score


# Synthetic linear pattern: y = 2*x1 + 3*x2 - 1*x3 + 5 + small noise.
CSV_TEXT = """x1,x2,x3,y
1.0,2.0,1.0,9.97
2.0,1.0,2.0,7.99
3.0,3.0,1.0,17.05
1.0,4.0,2.0,15.04
4.0,2.0,3.0,13.95
2.0,3.0,1.0,15.96
5.0,1.0,2.0,12.05
3.0,2.0,3.0,9.97
1.0,1.0,1.0,8.99
4.0,3.0,2.0,18.02
2.0,4.0,3.0,14.04
5.0,2.0,1.0,17.96
"""


def main() -> None:
    raw = np.loadtxt(io.StringIO(CSV_TEXT), delimiter=",", skiprows=1, dtype=np.float64)
    x = raw[:, 0:3]
    y = raw[:, 3]

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=4, random_state=42, shuffle=True
    )

    reg = LinearRegression()
    reg.fit(x_train, y_train)
    y_pred = reg.predict(x_test)
    r2 = float(r2_score(y_test, y_pred))

    result = {
        "case": "02_regression",
        "model": "sklearn.linear_model.LinearRegression",
        "random_state": 42,
        "n_train": int(x_train.shape[0]),
        "n_test": int(x_test.shape[0]),
        "n_features": int(x.shape[1]),
        "coef": [float(c) for c in reg.coef_],
        "intercept": float(reg.intercept_),
        "y_test": [float(v) for v in y_test],
        "y_pred": [float(v) for v in y_pred],
        "r2_score": r2,
        "tolerance_abs": 1e-09,
    }
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
