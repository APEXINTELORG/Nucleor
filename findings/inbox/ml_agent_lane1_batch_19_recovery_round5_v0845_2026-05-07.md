# ML Suite recovery smokes round 5 — Queue ML-22

Branch: fix/ml-22-batch-19-recovery-round5-v0845
Date: 2026-05-07

## Headline

**2 more deferred capabilities recovered**: Gaussian NB joint log likelihood and LM head logits. 4 attempted, 2 hit the same composed-Linear UB pattern (two_layer_relu, SwiGLU FFN, gaussian_nb predict argmax over multiple classes).

## Ship-ready (2)

| Smoke | Test approach |
|---|---|
| `ml_recover_gaussian_nb_joint_log_likelihood_f64` | 2-class Gaussian NB with means (0,0) vs (5,5), unit variance, equal priors. Query (0.1, 0.1) → class 0 likelihood > class 1. |
| `ml_recover_lm_head_logits_f64` | hidden=[[1,2]], W=[[1,0],[0,1],[1,1]], b=0 → logits = [1, 2, 3] (exact bit match). |

## Failed recoveries (3)

| Smoke | Why |
|---|---|
| `ml_recover_two_layer_relu_f64` | Composes nn_linear → ReLU → nn_linear. The base nn_linear path has the multi-step state UB. Failure consistent with ML-18 (`ml_recover_torch_linear_relu_f64` was unstable). |
| `ml_recover_swiglu_feed_forward_f64` | Composes 3 nn_linear-like projections → silu(gate) * up → down. Same nn_linear UB. |
| `ml_recover_gaussian_nb_predict_f64` | The argmax-over-classes path mutates a per-row "best class" tracker. Same min/max accumulator pattern. |

## Cumulative recovery surface (after ML-18+19+20+21+22): 15 capabilities

The two Linear-composition failures consolidate the diagnostic: **the nn_linear matmul-then-bias kernel is the gating UB** for any rod that uses Linear forward. Multi-head SDPA worked (ML-19) because its Q/K/V projections are likely inlined small matmuls; SwiGLU FFN and two-layer-relu use the explicit `nn_linear_f64` path which trips.

This refines the recovery selection rule:

- **Recovers cleanly:** kernels with single forward pass that don't call `nn_linear_f64` directly (LayerNorm fwd, log_softmax, sigmoid, softmax, scalar attention dot product, multi-head attention composition, top-k sort+select, top-p filter, PCA transform via direct matvec, SVC argmax via direct dot, NB joint log likelihood per class, last_row, categorical_sample, lm_head logits via direct h@W^T+b).
- **Does NOT recover:** kernels that go through `nn_linear_f64` OR mutate min/max/best-class tracker state.

Notable: `ml_recover_lm_head_logits_f64` PASSES while `ml_recover_torch_linear_relu_f64` FAILS — both use h@W^T+b math. The difference is the rod implementation: `ai_lm_head_logits_f64` does it inline; `nn_linear_f64` factors through tensor_f64_matmul + broadcast_add. The factoring is what triggers the UB.

## Build / drift

- 2/2 ship-ready build clean.
- 2/2 stable across 30 consecutive runs.
- Drift gate clean.

End of finding.
