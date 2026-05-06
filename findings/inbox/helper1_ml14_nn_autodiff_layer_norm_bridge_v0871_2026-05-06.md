# Helper1 v0871 - ML-14 NN/autodiff LayerNorm bridge

## Summary

This slice extends the existing ML-14 NN/autodiff bridge beyond Dense into
LayerNorm without adding new runtime ABI or compiler lowering.

Changed files:

- `stdlib/rods/nn_autodiff.nr`
- `tests/features/nn_autodiff_layer_norm_bridge_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## What changed

- Added `nn_autodiff_register_layer_norm()`.
- Added `nn_layer_norm_ad(input_ad, gamma_bits, beta_bits, eps_bits)`.
- The bridge lowers LayerNorm into existing scalar tape operations:
  mean, variance, epsilon-stabilized reciprocal standard deviation,
  per-element gamma scale, and beta shift.
- Added a focused fixture that checks:
  - value parity against `nn_layer_norm`;
  - input-gradient parity against `nn_layer_norm_backward` for a one-hot output gradient;
  - `differentiable.nr` registration for `nuc_nn_layer_norm`;
  - limitations text stays honest about remaining bridge gaps.

## Validation

Commands run:

```powershell
git diff --check -- stdlib/rods/nn_autodiff.nr tests/features/nn_autodiff_layer_norm_bridge_smoke.nr
.\bin\nucleor.exe build tests\features\nn_autodiff_layer_norm_bridge_smoke.nr -o helper1_nn_autodiff_layer_norm --no-cache
.\target\helper1_nn_autodiff_layer_norm.exe
bash tools/verify.sh --only "test features/nn_autodiff_layer_norm_bridge_smoke"
bash tools/verify.sh --only "test features/nn_autodiff_dense_bridge_smoke"
bash tools/verify.sh --only "test features/nn_norm_layers_smoke"
```

Result: all passed.

## Residual ML-14 gaps

- Dense and LayerNorm now have scalar-tape input-gradient bridges.
- Parameter gradients still use the explicit `nn.nr` backward/optimizer surfaces.
- BatchNorm, convolution, and attention bridge coverage remains open.
- No opaque registered NN layer op exists yet.
- Compiler-side `@differentiable` lowering into these bridge surfaces remains open.
