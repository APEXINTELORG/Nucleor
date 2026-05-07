# ML Suite boosting parity rod batch — Queue ML-13

Branch: fix/ml-13-batch-10-boosting-parity-rods-v0845
Date: 2026-05-07

## Headline

Lands **2 of 8 boosting parity rods** at 30-run stability. Both ship-ready are diagnostic outputs (leaf indices, decision-path indicators); the predict_margin / predict_proba / predict_label paths exhibit the same latent UB class that has hampered ML-9 / ML-10 / ML-11 / ML-12.

## Ship-ready (2)

| Rod | Surface |
|---|---|
| `ml_xgboost_tree_leaf_indices_f64` | dense + sparse `pred_leaf=True` parity |
| `ml_xgboost_tree_path_indicator_f64` | dense + sparse decision-path indicator parity |

## Deferred (6)

| Rod | Symptom |
|---|---|
| `xgboost_stump_ensemble_predict_f64` | predict_label path has UB (see ML-4 §5 for original investigation — the `boost_facade` smoke needed hand-authoring for this exact reason) |
| `xgboost_stump_contrib_f64` | additive-contribution accumulator UB |
| `xgboost_tree_ensemble_missing_predict_f64` | multi-depth tree traversal w/ missing-value routing UB |
| `xgboost_sparse_tree_predict_f64` | sparse CSR scan UB |
| `lightgbm_multiclass_tree_predict_f64` | multiclass softmax accumulator UB |
| `catboost_categorical_tree_predict_f64` | categorical equality-split tree UB |

End of finding.
