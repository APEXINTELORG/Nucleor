# Helper1 v0872 - ML-14 NN/autodiff BatchNorm bridge

## Summary

This slice extends the ML-14 NN/autodiff bridge to BatchNorm using only
stdlib-level scalar tape composition. No runtime ABI, compiler, generated
binary, bootstrap, or gate-script files were touched.

Changed files:

- `stdlib/rods/nn_autodiff.nr`
- `tests/features/nn_autodiff_batch_norm_bridge_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## What changed

- Added `nn_autodiff_register_batch_norm()`.
- Added `nn_batch_norm_ad(input_ad, n_samples, feat_dim, gamma_bits, beta_bits, eps_bits)`.
- The bridge lowers per-feature BatchNorm mean, variance, epsilon-stabilized
  normalization, gamma scale, and beta shift into existing autodiff tape nodes.
- Added a focused fixture that checks:
  - value parity against `nn_batch_norm`;
  - input-gradient parity against `nn_batch_norm_backward`;
  - `differentiable.nr` registration for `nuc_nn_batch_norm`;
  - limitations text remains honest about convolution/attention and compiler-lowering gaps.

## Validation

Commands run:

```powershell
git diff --check -- stdlib/rods/nn_autodiff.nr tests/features/nn_autodiff_batch_norm_bridge_smoke.nr
.\bin\nucleor.exe build tests\features\nn_autodiff_batch_norm_bridge_smoke.nr -o helper1_nn_autodiff_batch_norm --no-cache
.\target\helper1_nn_autodiff_batch_norm.exe
bash tools/verify.sh --only "test features/nn_autodiff_batch_norm_bridge_smoke"
bash tools/verify.sh --only "test features/nn_autodiff_layer_norm_bridge_smoke"
bash tools/verify.sh --only "test features/nn_autodiff_dense_bridge_smoke"
bash tools/verify.sh --only "test features/nn_norm_layers_smoke"
```

Result: all passed.

## Residual ML-14 gaps

- Dense, LayerNorm, and BatchNorm now have scalar-tape input-gradient bridges.
- Parameter gradients still use explicit `nn.nr` backward/optimizer surfaces.
- Convolution and attention bridge coverage remains open.
- No opaque registered NN layer op exists yet.
- Compiler-side `@differentiable` lowering into these bridge surfaces remains open.
