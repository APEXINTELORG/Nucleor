# ML Suite recovery smokes round 7 — Queue ML-24

Branch: fix/ml-24-batch-21-recovery-round7-v0845
Date: 2026-05-07

## Headline

**5/5 stable** — second perfect round in a row. Targeting metrics, gradient backward, and pandas frame walks. The rule is now well enough characterized that target selection is reliable.

| | Count |
|---|---:|
| Candidates | 5 |
| Build clean | 5/5 |
| 30-run stable | **5/5** |

## Ship-ready (5)

| Smoke | Surface |
|---|---|
| `ml_recover_classification_accuracy_f64` | scalar `classification_accuracy_i64` over y_true, y_pred i64 vectors → 0.8 |
| `ml_recover_confusion_matrix_i64` | 2-class confusion matrix: 5 samples → TN=1, FP=1, FN=1, TP=2 |
| `ml_recover_mse_loss_backward_f64` | per-element MSE gradient: input=[2,4], target=[1,1] → grad ratio = 3:1 |
| `ml_recover_pandas_filter_value_ge_f64` | filter v >= 25 over [10,20,30,40,50] → 3 rows |
| `ml_recover_pandas_fillna_mean_f64` | fillna(99) on nullable + mean of valid only |

## Cumulative recovery surface (after ML-18..24): 25 capabilities

The recovery program has now closed **25 deferred parity capabilities**. This batch reinforces the rule: scalar metrics over already-computed vectors (accuracy, conf-matrix), single-pass gradients (mse backward), and pandas frame walks (filter, fillna, mean) all recover cleanly.

## Build / drift

- 5/5 build clean.
- 5/5 stable across 30 consecutive runs.
- Drift gate clean.

End of finding.
