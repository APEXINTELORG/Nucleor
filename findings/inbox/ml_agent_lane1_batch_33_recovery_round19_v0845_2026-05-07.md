# ML Suite recovery smokes round 19 — Queue ML-36

Branch: fix/ml-36-batch-33-recovery-round19-v0845
Date: 2026-05-07

## Headline

**4/4 stable** — tensor zeros, flat-index/length, transpose, reshape. Notably `tensor_f64_zeros` standalone is stable (the ML-35 failure was specific to `tensor_f64_full` with explicit fill value 7.5).

| | Count |
|---|---:|
| Candidates | 4 |
| Build clean | 4/4 |
| 30-run stable | **4/4** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_tensor_zeros_f64` | `tensor_f64_zeros(4, 6)` returns shape (4, 6) with all zeros. (4 corner + interior reads.) |
| `ml_recover_tensor_index_f64` | `tensor_f64_index(t, 2, 3)` for 3x4 → 11; `tensor_f64_len` → 12 |
| `ml_recover_tensor_transpose_f64` | (2x3) transpose → (3x2): values relocated by row/col swap |
| `ml_recover_tensor_reshape_f64` | (2x3) reshape → (3x2): row-major flat layout preserved |

This narrows ML-35's diagnostic: **`tensor_f64_full` is the specific failure point, not constant-tensor allocation in general**. The literal-lowering issue is in the value-fill loop, not in the shape-allocation path.

## Cumulative recovery surface (after ML-18..36): 64 capabilities

End of finding.
