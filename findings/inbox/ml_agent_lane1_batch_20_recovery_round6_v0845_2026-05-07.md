# ML Suite recovery smokes round 6 — Queue ML-23

Branch: fix/ml-23-batch-20-recovery-round6-v0845
Date: 2026-05-07

## Headline

**5/5 stable** — best recovery round yet. Targeting axis-direct ops (argmax, max), gradient backwards, and pandas join+dropna. All five recover cleanly because each is either an axis-direct tensor op (no `nn_linear_f64` factoring) or a frame walk (no tensor-typed Vec multi-step state).

| | Count |
|---|---:|
| Candidates | 5 |
| Build clean | 5/5 |
| 30-run stable | **5/5** |

## Ship-ready (5)

| Smoke | Surface | Test approach |
|---|---|---|
| `ml_recover_argmax_axis1_f64` | `tensor_f64_argmax_axis1` | 3×3 matrix with known per-row argmax (cols 1, 0, 2) |
| `ml_recover_max_axis1_f64` | `tensor_f64_max_axis1` | same matrix, per-row max values 5, 7, 9 |
| `ml_recover_relu_backward_f64` | `nn_relu_backward_f64` | grad gating: input ≤ 0 → 0 grad; input > 0 → grad passes through |
| `ml_recover_pandas_inner_join_f64` | `frame_i64_f64_inner_join` | left keys [1,2,3], right keys [2,3,4] → inner produces 2 rows on keys 2 and 3 |
| `ml_recover_pandas_dropna_f64` | `frame_i64_nullable_f64_dropna` | 4-row frame with valid mask [1,0,1,1] → dropna returns 3 rows |

## Cumulative recovery surface (after ML-18..23): 20 capabilities

The recovery program has now closed **20 deferred parity capabilities** through hand-authored minimal smokes — across LayerNorm, SVC, PCA, attention, softmax, top-k/top-p, log_softmax, sigmoid, axis ops, gradients, joins, nullable handling, last-row, categorical sampling, NB joint likelihood, LM head, multi-head attention.

This batch's 5/5 success rate confirms the recovery rule is mature:

- **Pandas frame walks recover.** Both inner_join and dropna walk Vec<i64>/Vec<f64> mutating an output Vec — this works because the Vec accumulator is a return value, not threaded through intermediate tensor structs.
- **Axis-direct tensor ops recover.** argmax_axis1 / max_axis1 walk one row at a time and emit a single output Vec — no min/max tracker mutation across multi-step state.
- **Single-step gradients recover.** `nn_relu_backward_f64` is a single elementwise gating op; no broadcast-add-bias or matvec factoring like `nn_linear`.

## Build / drift

- 5/5 build clean.
- 5/5 stable across 30 consecutive runs.
- Drift gate clean.

End of finding.
