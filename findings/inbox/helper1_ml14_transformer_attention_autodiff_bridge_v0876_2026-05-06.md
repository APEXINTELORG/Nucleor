# Helper1 Finding: ML-14 Transformer Attention Autodiff Bridge (v0876)

Date: 2026-05-06
Branch: `fix/helper1-qm6-mps-joint-prob-v0831`
Scope: ML-14 transformer/autodiff bridge coverage, classic attention forward path with Q/K/V input gradients

## Summary

`transformer_autodiff.nr` now exposes `tf_attention_split_ad(...)` and `tf_attention_ad(...)`, which lower classic transformer attention into scalar autodiff tape nodes and register `nuc_tf_attention_split` through `differentiable.nr`.

The fixture checks value parity against `tf_attention_split` and `tf_attention_split_masked`, then checks focused softmax-gradient coverage for V weights and the Q input.

## Files Changed

- `stdlib/rods/transformer_autodiff.nr`
- `stdlib/rods/nn_autodiff.nr`
- `tests/features/nn_autodiff_attention_bridge_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Validation

- `git diff --check`
- `.\bin\nucleor.exe build tests\features\nn_autodiff_attention_bridge_smoke.nr -o helper1_nn_autodiff_attention --no-cache`
- `.\target\helper1_nn_autodiff_attention.exe`
- `bash tools/verify.sh --only "test features/nn_autodiff_attention_bridge_smoke"`
- `bash tools/verify.sh --only "test features/transformer_attention_smoke"`
- `bash tools/verify.sh --only "test features/nn_autodiff_depthwise_conv2d_bridge_smoke"`

## Residual Risk

- The bridge is still per-scalar tape lowering, not one opaque registered attention op.
- Flash/GQA/MLA attention variants remain outside this bridge.
- Parameter-gradient tape integration remains outside this bridge.
- Compiler-side `@differentiable` lowering remains open.
