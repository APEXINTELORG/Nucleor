# ML Suite recovery smokes round 24 — Queue ML-41

Branch: fix/ml-41-batch-38-recovery-round24-v0845
Date: 2026-05-07

## Headline

**3/3 stable**: BCE-with-logits backward, SGD step, SGD momentum step. Notable: SGD momentum step (with state buffer) recovers — was deferred in ML-10 PyTorch batch.

| | Count |
|---|---:|
| Candidates | 3 |
| Build clean | 3/3 |
| 30-run stable | **3/3** |

## Ship-ready (3)

| Smoke | Surface |
|---|---|
| `ml_recover_bce_with_logits_backward_f64` | gradient: opposite sign for target 0 vs 1, equal magnitude when logits=0 |
| `ml_recover_sgd_step_f64` | param[i] -= lr * grad[i]: param=[1,2], grad=[0.1,0.2], lr=0.5 → [0.95, 1.9] |
| `ml_recover_sgd_momentum_step_f64` | returns SgdMomentumStepF64{param, velocity}: with v=0, momentum=0.9, lr=0.5 → first step gives v=grad, p = orig - 0.5*grad |

The SGD momentum recovery is significant — it's a stateful optimizer step that was lumped into the deferred ML-10 set with the heavier training-loop variants. The single-step API recovers cleanly.

## Cumulative recovery surface (after ML-18..41): 77 capabilities

End of finding.
