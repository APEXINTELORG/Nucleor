# ML Suite recovery smokes round 9 — Queue ML-26

Branch: fix/ml-26-batch-23-recovery-round9-v0845
Date: 2026-05-07

## Headline

**4/4 stable**. Targeting scalar reductions, single-head attention scoring, scalar L1 loss, and frame→tensor projection. All stable across 30 runs.

| | Count |
|---|---:|
| Candidates | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_tensor_sum_mean_f64` | scalar `tensor_f64_sum` + `tensor_f64_mean` over 2x3 → 21, 3.5 |
| `ml_recover_attention_head_score_f64` | per-head Q/K dot product with explicit head slicing — head 0 = 11, head 1 = 0 |
| `ml_recover_l1_loss_f64` | scalar `nn_l1_loss_f64` (mean abs error) → 2.0 |
| `ml_recover_values_tensor_f64` | `frame_i64_f64_values_tensor` projection: frame value column → TensorF64 |

## Cumulative recovery surface (after ML-18..26): 33 capabilities

End of finding.
