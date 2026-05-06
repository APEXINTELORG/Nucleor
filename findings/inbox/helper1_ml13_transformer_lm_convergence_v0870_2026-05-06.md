# Helper1 Finding - ML-13 Transformer LM Convergence (v0870)

## Summary

ML-13 P2c now has a transformer small-LM-head convergence fixture:

- Added `tf_cross_entropy_grad(...)` to `transformer.nr`.
- Runtime gradient returns `softmax(logits) - onehot(target)`.
- Added `tests/features/transformer_lm_convergence_smoke.nr`.
- The fixture trains two next-token logit rows for the alternating sequence `0 -> 1`, `1 -> 0`.
- It asserts material cross-entropy loss reduction and target-token probabilities above `0.90`.

This is a real logits/cross-entropy/gradient/Adam update oracle, not a softmax-only smoke.

## Evidence

Focused fixture:

- `tests/features/transformer_lm_convergence_smoke.nr`

Validated commands:

```powershell
git diff --check -- stdlib/runtime/transformer_rt.c stdlib/rods/transformer.nr tests/features/transformer_lm_convergence_smoke.nr
.\bin\nucleor.exe build tests\features\transformer_lm_convergence_smoke.nr -o helper1_transformer_lm_convergence --no-cache
.\target\helper1_transformer_lm_convergence.exe
bash tools/verify.sh --only "test features/transformer_lm_convergence_smoke"
bash tools/verify.sh --only "test features/transformer_smoke"
bash tools/verify.sh --only "test features/transformer_causal_encoder_decoder_smoke"
bash tools/verify.sh --only "test features/loss_smoke"
```

The fixture checks:

- `tf_cross_entropy_grad` produces a usable training gradient for logits.
- Adam logit updates reduce pair loss below 20% of initial loss.
- `P(next=1 | token=0) > 0.90`.
- `P(next=0 | token=1) > 0.90`.

## Files Changed

- `stdlib/runtime/transformer_rt.c`
- `stdlib/rods/transformer.nr`
- `tests/features/transformer_lm_convergence_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Residual

This closes the small-LM-head convergence oracle. Full transformer block training through attention/feedforward weights remains future work because the transformer rod still lacks attention/feedforward backward surfaces.
