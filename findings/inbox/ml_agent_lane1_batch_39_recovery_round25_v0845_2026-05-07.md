# ML Suite recovery smokes round 25 — Queue ML-42

Branch: fix/ml-42-batch-39-recovery-round25-v0845
Date: 2026-05-07

## Headline

**1/2 stable**: AdamW single-step recovers. Cross-entropy backward (which embeds softmax) does not — confirms the softmax-in-gradient pattern trips UB just like the NB predict_proba normalization.

| | Count |
|---|---:|
| Candidates | 2 |
| Build clean | 2/2 |
| 30-run stable | **1/2** |

## Ship-ready (1)

| Smoke | Surface |
|---|---|
| `ml_recover_adamw_step_f64` | single AdamW update step with explicit state buffers (param + exp_avg + exp_avg_sq); param decreases in gradient direction by ~lr |

The AdamW recovery is **significant** — it was deferred in the ML-10 PyTorch batch alongside the heavier training-loop variants. Combined with ML-41's SGD momentum recovery, both single-step stateful optimizer APIs are now production-ready. The deferred items in ML-10 were specifically the **multi-step training loops** that compose Linear → loss → optimizer in a single call; the underlying optimizer-step kernels themselves recover.

## Failed (1)

| Smoke | Why |
|---|---|
| `ml_recover_cross_entropy_backward_f64` | softmax-in-gradient pattern — same UB family as NB predict_proba normalization (ML-33) and temperature_top_p composition (ML-37) |

## Cumulative recovery surface (after ML-18..42): 78 capabilities

End of finding.
