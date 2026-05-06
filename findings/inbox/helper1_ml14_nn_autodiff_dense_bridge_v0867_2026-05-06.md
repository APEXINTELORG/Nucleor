# Helper1 Finding - ML-14 NN Autodiff Dense Bridge (v0867)

## Summary

ML-14 is now partially closed with the first `nn` / `autodiff` bridge:

- Added `nn_autodiff.nr`.
- Added `nn_dense_forward_ad(layer, input_ad)`, which lowers a Dense forward pass into scalar autodiff tape nodes.
- Added Dense parameter accessors in `nn.nr` / `nn_rt.c` for dimensions, weights, and bias.
- Registered the dense surface through `differentiable.nr` so the bridge is visible as a differentiable NN entry point.

This proves Dense value parity and input gradients through the autodiff tape without compiler changes.

## Evidence

Focused fixture:

- `tests/features/nn_autodiff_dense_bridge_smoke.nr`

Validated commands:

```powershell
git diff --check
.\bin\nucleor.exe build tests\features\nn_autodiff_dense_bridge_smoke.nr -o helper1_nn_autodiff_dense_bridge --no-cache
.\target\helper1_nn_autodiff_dense_bridge.exe
bash tools/verify.sh --only "test features/nn_autodiff_dense_bridge_smoke"
bash tools/verify.sh --only "test features/autodiff_smoke"
bash tools/verify.sh --only "test features/nn_smoke"
```

The fixture checks:

- `nn_dense_forward_ad` matches `nuc_nn_dense_forward` for Dense output value.
- `ad_grad(y, x0)` and `ad_grad(y, x1)` match the layer weights.
- `differentiable_is("nuc_nn_dense_forward")` sees the registered bridge surface.
- `nn_autodiff_limitations()` names the shipped input-gradient scope and parameter-gradient residual.

## Files Changed

- `stdlib/runtime/nn_rt.c`
- `stdlib/rods/nn.nr`
- `stdlib/rods/nn_autodiff.nr`
- `tests/features/nn_autodiff_dense_bridge_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Residual

This is a conservative P2a bridge. It supports Dense input gradients by decomposing the layer into existing scalar tape operations. It does not yet make Dense one opaque registered autodiff op, does not produce parameter gradients through the global autodiff tape, and does not cover convolution, normalization, attention, or compiler-side `@differentiable` lowering.
