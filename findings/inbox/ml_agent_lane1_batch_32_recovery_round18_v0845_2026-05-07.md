# ML Suite recovery smokes round 18 — Queue ML-35

Branch: fix/ml-35-batch-32-recovery-round18-v0845
Date: 2026-05-07

## Headline

**2/3 stable**: tensor div, tensor slice. Failed: `tensor_f64_full(2, 5, 7.5)` — deterministic fill-value mismatch on 7.5; likely a residual f64 literal lowering quirk (echoes the historical NUC-FEEDBACK-005/006 family flagged in ML-2 §6).

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **2/3** |

## Ship-ready (2)

| Smoke | Surface |
|---|---|
| `ml_recover_tensor_div_f64` | `tensor_f64_div` pointwise on 2x2: [[10,20],[30,40]] / [[2,4],[5,8]] = [[5,5],[6,5]] |
| `ml_recover_tensor_slice_f64` | `tensor_f64_slice(rows[0..2), cols[1..3))` on 3x3 → 2x2 |

## Failed (1)

| Smoke | Why |
|---|---|
| `ml_recover_tensor_full_zeros_f64` | `tensor_f64_full(2, 5, 7.5)` returns a tensor where `tensor_f64_at(&f, 0, 0)` is not 7.5. Same kind of f64 literal lowering issue documented in master's `NUC-FEEDBACK-005`/`006` (closed in v0.3.130 historically; may have a regression in 0.8.323 for value-fill paths). The `tensor_f64_zeros` portion in the same smoke worked — it's the non-zero fill that fails. Surfaced for Nucleor-language review. |

The `tensor_f64_full` failure is a fresh diagnostic worth flagging separately: it's not the move/borrow UB pattern that has dominated the deferred catalog — it's a different category (literal lowering / scalar broadcast). May be quick to fix at the language layer.

## Cumulative recovery surface (after ML-18..35): 60 capabilities

End of finding.
