# ML Suite recovery smokes round 14 — Queue ML-31

Branch: fix/ml-31-batch-28-recovery-round14-v0845
Date: 2026-05-07

## Headline

**4/4 stable**. Tensor primitives: select_rows (gather), scale (scalar mul), powi (pointwise int power), reduce_axis1 (per-row sum). All 4/4 stable across 30 runs.

| | Count |
|---|---:|
| Candidates | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_tensor_select_rows_f64` | gather rows by indices: pick rows [3,0,2] from 4×2 matrix |
| `ml_recover_tensor_scale_f64` | scalar multiply: tensor * 2.5 |
| `ml_recover_tensor_powi_f64` | pointwise integer power: tensor^2 |
| `ml_recover_tensor_reduce_axis1_f64` | per-row sum reduction: row 0 sum=6, row 1 sum=15 |

## Cumulative recovery surface (after ML-18..31): 51 capabilities

End of finding.
