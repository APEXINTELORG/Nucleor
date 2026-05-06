# Helper1 ML-13 P1 NN XOR Convergence v0864

## Summary

Closed the first `nn.nr` convergence evidence gap:

- Added a deterministic XOR convergence fixture using a 2-layer MLP.
- The fixture exercises dense forward/backward, sigmoid backward,
  `dense_zero_grad`, Adam timestep/update sequencing, and multi-layer gradient
  flow together.
- It asserts the learned predictions separate XOR classes rather than only
  checking that handles compile or link.

## Evidence

Focused fixture:

- `tests/features/nn_xor_convergence_smoke.nr`

The fixture trains:

- `Dense(2, 8) -> Sigmoid -> Dense(8, 1) -> Sigmoid`
- 4000 deterministic Adam epochs over the four XOR samples.

Pass condition:

- `p(0,0) < 0.35`
- `p(0,1) > 0.65`
- `p(1,0) > 0.65`
- `p(1,1) < 0.35`

## Residual Gaps

- This is `nn.nr` convergence only. GNN, SSM, transformer, and diffusion
  convergence remain separate ML-13 P2 work.
- The test uses XOR classification thresholds rather than a serialized loss
  ledger. That keeps the fixture cheap enough for the normal gate while still
  proving the training path is functional.

## Files Changed

- `tests/features/nn_xor_convergence_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
