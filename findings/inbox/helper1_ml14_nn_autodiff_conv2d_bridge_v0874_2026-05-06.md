# Helper1 Finding: ML-14 NN Autodiff Conv2D Bridge (v0874)

Date: 2026-05-06
Branch: `fix/helper1-qm6-mps-joint-prob-v0831`
Scope: ML-14 NN/autodiff bridge coverage, Conv2D forward path with input gradients

## Summary

`nn_autodiff.nr` now exposes `nn_conv2d_ad(...)`, which lowers Conv2D into scalar autodiff tape nodes and registers `nuc_nn_conv2d` through `differentiable.nr`.

The fixture checks value parity against `nn_conv2d`, then checks input-gradient parity against `nn_conv2d_backward` for a focused single-channel Conv2D case.

## Files Changed

- `stdlib/rods/nn_autodiff.nr`
- `tests/features/nn_autodiff_conv2d_bridge_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Validation

- `git diff --check -- stdlib/rods/nn_autodiff.nr tests/features/nn_autodiff_conv2d_bridge_smoke.nr`
- `.\bin\nucleor.exe build tests\features\nn_autodiff_conv2d_bridge_smoke.nr -o helper1_nn_autodiff_conv2d --no-cache`
- `.\target\helper1_nn_autodiff_conv2d.exe`
- `bash tools/verify.sh --only "test features/nn_autodiff_conv2d_bridge_smoke"`
- `bash tools/verify.sh --only "test features/nn_convolution_layers_smoke"`

## Residual Risk

- The bridge is still per-scalar tape lowering, not one opaque registered layer op.
- Parameter-gradient tape integration remains outside this bridge; existing `nn.nr` backward helpers remain the parameter-gradient source.
- Depthwise Conv2D, attention bridge coverage, and compiler-side `@differentiable` lowering remain open.
