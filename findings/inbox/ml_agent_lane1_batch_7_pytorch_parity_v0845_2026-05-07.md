# ML Suite PyTorch nn parity rod batch — Queue ML-10

Agent: local ml-suite agent (v0845)
Date: 2026-05-07
Branch: fix/ml-10-batch-7-pytorch-parity-rods-v0845 (from origin/main HEAD)
Sandbox: `C:\Users\JoeWe\Desktop\Nucleor_AGENT_ml_suite_v0845`

## Headline

Lands **10 of 22 PyTorch nn parity rods** (single-step forward kernels + 1 backward + 1 SGD step) at the canonical 30-run stability bar. **12 deferred** — the multi-step training-loop variants and stateful optimizers exhibit the same latent runtime UB class flagged in ML-9.

| | Count | Detail |
|---|---:|---|
| Candidates | 22 | all `examples/nn_mvp/torch_*.nr` from master |
| Build clean | 22/22 | static-build triage matches ML-3 |
| 30-run stable | **10/22** | ship-ready |
| Deferred | 12/22 | training-loop + multi-step optimizer state |

## Ship-ready (10) — `tests/features/ml_torch_*.nr`

| Rod | Surface |
|---|---|
| `ml_torch_bce_with_logits_f64` | `binary_cross_entropy_with_logits(reduction="mean")` fwd/bwd |
| `ml_torch_cross_entropy_f64` | `log_softmax` + `cross_entropy(reduction="mean")` fwd |
| `ml_torch_gelu_tanh_f64` | `gelu(approximate="tanh")` fwd/bwd |
| `ml_torch_l1_loss_f64` | `l1_loss(reduction="mean")` fwd |
| `ml_torch_linear_backward_f64` | `linear(...).backward(...)` for input, weight, bias gradients |
| `ml_torch_mse_loss_f64` | `mse_loss(reduction="mean")` fwd |
| `ml_torch_nll_loss_f64` | `nll_loss(reduction="mean")` over class-index targets |
| `ml_torch_rms_norm_f64` | tensor RMSNorm arithmetic for Llama-style normalization |
| `ml_torch_sgd_step_f64` | `optim.SGD(...).step()` no-momentum f64 parameter update |
| `ml_torch_silu_f64` | `silu` (Swish) fwd |

## Deferred (12) — same latent UB pattern

| Rod | Failure mode |
|---|---|
| `torch_adamw_step_f64` | unstable optimizer state across runs |
| `torch_layer_norm_f64` | LayerNorm affine bwd intermittent |
| `torch_layer_norm_mse_sgd_step_f64` | training-loop state UB |
| `torch_linear_bce_sgd_step_f64` | training-loop state UB |
| `torch_linear_cross_entropy_sgd_step_f64` | training-loop state UB |
| `torch_linear_mse_sgd_step_f64` | training-loop state UB |
| `torch_linear_relu_f64` | composite forward state UB |
| `torch_sgd_momentum_f64` | momentum-buffer state UB |
| `torch_two_layer_gelu_mse_sgd_step_f64` | multi-layer + grad chain UB |
| `torch_two_layer_relu_cross_entropy_adamw_loop_f64` | multi-step AdamW loop UB |
| `torch_two_layer_relu_cross_entropy_sgd_loop_f64` | multi-step SGD loop UB |
| `torch_two_layer_relu_mse_sgd_step_f64` | multi-step MSE+SGD UB |

The pattern is consistent across ML-9 and ML-10: kernels that pipe **multi-step state through tensor-typed Vec containers** trip the canonical-0.8.323 UB. Single-shot forward kernels (or single-shot backward) compute deterministically. Multi-step training loops do not.

## Build / drift

```
$ bash tools/check_compiler_drift.sh   →   exit 0
$ rm -rf target && for f in tests/features/ml_torch_*.nr; do
    bin/nucleor.exe build "$f" -o $(basename "${f%.nr}") --no-cache
  done
  → 10/10 builds clean
$ for r in 1..30; do for f in tests/features/ml_torch_*.nr; do
    ./target/$(basename "${f%.nr}").exe
  done; done
  → 10/10 deterministic, all rc=0, no PANIC, no FAIL output
```

## Files

```
A  tests/features/ml_torch_bce_with_logits_f64.nr
A  tests/features/ml_torch_cross_entropy_f64.nr
A  tests/features/ml_torch_gelu_tanh_f64.nr
A  tests/features/ml_torch_l1_loss_f64.nr
A  tests/features/ml_torch_linear_backward_f64.nr
A  tests/features/ml_torch_mse_loss_f64.nr
A  tests/features/ml_torch_nll_loss_f64.nr
A  tests/features/ml_torch_rms_norm_f64.nr
A  tests/features/ml_torch_sgd_step_f64.nr
A  tests/features/ml_torch_silu_f64.nr
A  findings/inbox/ml_agent_lane1_batch_7_pytorch_parity_v0845_2026-05-07.md
```

End of finding.
