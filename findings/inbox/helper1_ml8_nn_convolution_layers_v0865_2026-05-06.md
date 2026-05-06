# Helper1 Finding - ML-8 NN Convolution Layers (v0865)

## Summary

ML-8 is now partially closed with functional NN convolution kernels in `nn.nr`:

- `nn_conv1d(...)` and `nn_conv1d_backward(...)`
- `nn_conv2d(...)` and `nn_conv2d_backward(...)`
- `nn_depthwise_conv2d(...)` and `nn_depthwise_conv2d_backward(...)`

The backward helpers return a two-handle vector `[grad_input, grad_kernel]`.

## Evidence

Focused fixture:

- `tests/features/nn_convolution_layers_smoke.nr`

Validated commands:

```powershell
git diff --check
.\bin\nucleor.exe build tests\features\nn_convolution_layers_smoke.nr -o helper1_nn_convolution_layers --no-cache
.\target\helper1_nn_convolution_layers.exe
bash tools/verify.sh --only "test features/nn_convolution_layers_smoke"
bash tools/verify.sh --only "test features/nn_smoke"
bash tools/verify.sh --only "test features/conv_smoke"
```

The fixture checks:

- Conv1D forward output and exact input/kernel gradients.
- Conv2D forward output and exact input/kernel gradients.
- Depthwise Conv2D forward output and exact input/kernel gradients.

## Files Changed

- `stdlib/runtime/nn_rt.c`
- `stdlib/rods/nn.nr`
- `tests/features/nn_convolution_layers_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Residual

This closes the missing functional convolution kernel and gradient surface. It does not yet add optimizer-owned stateful convolution layer objects analogous to `nn_dense`.
