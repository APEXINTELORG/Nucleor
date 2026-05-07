# ML Suite recovery smokes round 8 — Queue ML-25

Branch: fix/ml-25-batch-22-recovery-round8-v0845
Date: 2026-05-07

## Headline

**4/5 stable**: GELU-tanh backward, NLL loss, pandas head, pandas tail. Failed: `sequence_lm_head_last_logits` (composes last_row + lm_head — even though both individually pass, the composition trips UB).

| | Count |
|---|---:|
| Candidates | 5 |
| Build clean | 5/5 |
| 30-run stable | **4/5** |

## Ship-ready (4)

| Smoke | Surface |
|---|---|
| `ml_recover_gelu_tanh_backward_f64` | `nn_gelu_tanh_backward_f64`: derivative ≈ 0.5 at 0, → 1 at large+, → 0 at large- |
| `ml_recover_nll_loss_f64` | scalar NLL loss over class-index targets: log_probs[i, target[i]] mean |
| `ml_recover_pandas_head_f64` | `frame_i64_f64_head(n)` returns first n rows |
| `ml_recover_pandas_tail_f64` | `frame_i64_f64_tail(n)` returns last n rows |

## Failed (1)

| Smoke | Why |
|---|---|
| `ml_recover_sequence_lm_head_last_logits_f64` | Composes `ai_last_row_f64` + `ai_lm_head_logits_f64` — the rod-side composition allocates an intermediate tensor and then projects it. Both individuals are stable (ML-21, ML-22) but the composed call exhibits UB. Refines the rule: **composition through intermediate tensor allocation may trigger UB** even when each component is independently stable. |

## Cumulative recovery surface (after ML-18..25): 29 capabilities

End of finding.
