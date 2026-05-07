# ML Suite recovery smokes round 17 — Queue ML-34

Branch: fix/ml-34-batch-31-recovery-round17-v0845
Date: 2026-05-07

## Headline

**4/4 stable**. Tensor pointwise add + mul, pandas filter > / <, boost stump-contribution row-sum.

| | Count |
|---|---:|
| Candidates | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_tensor_add_mul_f64` | `tensor_f64_add` and `tensor_f64_mul` pointwise on 2x2 |
| `ml_recover_pandas_filter_value_gt_f64` | `frame_i64_f64_filter_value_gt(25)` over [10,20,30,40,50] → 3 rows |
| `ml_recover_pandas_filter_value_lt_f64` | `frame_i64_f64_filter_value_lt(25)` over same → 2 rows |
| `ml_recover_boost_sum_contrib_f64` | `boost_stump_ensemble_sum_contrib_f64` per-row sum across stumps: [0.3, 0, 2.0] for [[0.1,0.2],[0.5,-0.5],[1,1]] |

## Cumulative recovery surface (after ML-18..34): 58 capabilities

End of finding.
