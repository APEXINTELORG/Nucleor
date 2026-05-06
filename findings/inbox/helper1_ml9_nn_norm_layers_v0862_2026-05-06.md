# Helper1 ML-9 NN Normalization Layers v0862

## Summary

Closed the stdlib/runtime/test/doc portion of ML-9:

- `nn_layer_norm(input, gamma, beta, eps_bits)` now exposes learnable layer
  normalization over one f64-bit vector.
- `nn_layer_norm_backward(input, gamma, grad, eps_bits)` returns
  `[grad_input, grad_gamma, grad_beta]`.
- `nn_batch_norm(input, n_samples, feat_dim, gamma, beta, eps_bits)` now
  exposes batch normalization over a flat row-major batch matrix.
- `nn_batch_norm_backward(input, n_samples, feat_dim, gamma, grad, eps_bits)`
  returns `[grad_input, grad_gamma, grad_beta]`.

This changes `nn.nr` from dense/activation-only training primitives to a
surface with real trainable normalization layers.

## Evidence

Focused fixture:

- `tests/features/nn_norm_layers_smoke.nr`

The fixture checks callable forward and backward behavior:

- Layer norm maps `[1,2,3]` to approximately
  `[-1.224744, 0, 1.224744]`.
- Layer norm backward returns near-zero `grad_input` for uniform upstream
  gradient and expected `grad_gamma` / `grad_beta`.
- Batch norm over a 2x2 row-major batch maps feature columns to
  `[-1,-1,1,1]` under unit gamma / zero beta.
- Batch norm backward returns expected zero `grad_input`, zero `grad_gamma`,
  and `grad_beta=[2,2]` for uniform upstream gradient.

## Residual Gaps

- This does not add convolutional layers (ML-8), convergence tests (ML-13), or
  autodiff tape integration (ML-14).
- The returned backward tuple is a Vec of opaque handles, matching existing rod
  conventions; compiler-visible tensor/tuple typing remains a separate lane.

## Files Changed

- `stdlib/runtime/nn_rt.c`
- `stdlib/rods/nn.nr`
- `tests/features/nn_norm_layers_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
