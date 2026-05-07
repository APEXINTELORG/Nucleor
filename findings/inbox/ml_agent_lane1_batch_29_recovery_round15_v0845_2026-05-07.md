# ML Suite recovery smokes round 15 — Queue ML-32

Branch: fix/ml-32-batch-29-recovery-round15-v0845
Date: 2026-05-07

## Headline

**2/2 stable** — DecisionTreeClassifier fully recovered through both surfaces (apply for leaf indices, predict_proba for class distributions).

| | Count |
|---|---:|
| Candidates | 2 |
| Build clean | 2/2 |
| 30-run stable | **2/2** |

## Ship-ready (2)

| Smoke | Surface |
|---|---|
| `ml_recover_decision_tree_apply_i64` | tiny 3-node tree (1 internal, 2 leaves), feature 0 split at 0.5; query [0.0] → leaf 1, query [1.0] → leaf 2 |
| `ml_recover_decision_tree_predict_proba_f64` | same tree shape; leaf 1 has class counts [8, 2] → [0.8, 0.2]; leaf 2 has [1, 9] → [0.1, 0.9] |

The tree-walk pattern (per-row recursive descent through node array) is a single-pass kernel — same shape as KNN raw search and pandas frame walks. Both DT surfaces recover cleanly.

## Cumulative recovery surface (after ML-18..32): 53 capabilities

End of finding.
