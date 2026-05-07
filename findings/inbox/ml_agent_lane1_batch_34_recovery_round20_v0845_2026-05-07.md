# ML Suite recovery smokes round 20 — Queue ML-37

Branch: fix/ml-37-batch-34-recovery-round20-v0845
Date: 2026-05-07

## Headline

**2/3 stable**: tensor row broadcast add, Gaussian NB log-probability output. Failed: `ai_temperature_top_p_f64` — confirms the composition-through-intermediate-tensor failure pattern.

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **2/3** |

## Ship-ready (2)

| Smoke | Surface |
|---|---|
| `ml_recover_broadcast_add_row_f64` | `tensor_f64_broadcast_add_row` (2x3) + (1x3) → adds row to each row |
| `ml_recover_gaussian_nb_predict_log_proba_f64` | `gaussian_nb_predict_log_proba_f64` outputs log probabilities (different code path than predict_proba which exponentiates) |

The Gaussian NB recovery is notable: `predict_log_proba` recovers cleanly while `predict_proba` (ML-33) does not. The exponentiation step in `predict_proba` is what trips the UB; the log-domain output bypasses it.

## Failed (1)

| Smoke | Why |
|---|---|
| `ml_recover_temperature_top_p_f64` | Composes `temperature_softmax` + `top_p` in a single call; same pattern as `sequence_lm_head_last_logits` (ML-25) failure — composition through intermediate tensor |

## Cumulative recovery surface (after ML-18..37): 66 capabilities

End of finding.
