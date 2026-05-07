# ML Suite recovery smokes round 23 — Queue ML-40

Branch: fix/ml-40-batch-37-recovery-round23-v0845
Date: 2026-05-07

## Headline

**3/3 stable**: scalar binary log loss, ROC AUC, and the GroupedStatsI64F64 struct-returning groupby (count + min + max per group).

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **3/3** |

## Ship-ready (3)

| Smoke | Surface |
|---|---|
| `ml_recover_binary_log_loss_f64` | scalar `binary_log_loss_i64_f64` over 4 confident-correct preds → ~0.164 |
| `ml_recover_binary_roc_auc_f64` | perfect-separation AUC = 1.0 for y=[0,0,1,1], scores=[0.1,0.2,0.8,0.9] |
| `ml_recover_pandas_groupby_count_min_max_f64` | `frame_i64_f64_groupby_count_min_max` returns `GroupedStatsI64F64` struct: 5 rows in 2 groups → key 1 (count=2, min=10, max=30), key 2 (count=3, min=20, max=50) |

The ROC AUC recovery is notable since it requires sort-by-score and rank-counting state — but with a "return single struct of vectors" pattern (similar to GaussianNB joint LL output), it stays single-pass.

## Cumulative recovery surface (after ML-18..40): 74 capabilities

End of finding.
