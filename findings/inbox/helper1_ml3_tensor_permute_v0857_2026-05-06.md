# Helper1 Finding - ML-3 tensor_nd Permute

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

The remaining ML-3 tensor permutation surface is closed for the
existing Tensor3D runtime representation.

New API:

- `tensor_permute(h, axes)` accepts a `Vec<i64>` axes permutation.
- It returns `0` for null handles, short/long axes, duplicate axes, or
  out-of-range axes.

## Evidence

`tests/features/tensor_nd_permute_smoke.nr` locks:

- `[2,3,4]` permuted by `[1,0,2]` becomes `[3,2,4]`;
- representative row-major values map to the expected source cells;
- duplicate axes return `0`;
- short axes return `0`;
- `tensor_limitations()` names `tensor_permute`.

## Residual Gap

ML-3's explicit runtime surface is now present. Remaining tensor gaps
are not permutation-specific: dtype support, compiler-visible tensor
shape types, and richer shape diagnostics are still future work.

Compiler audit diagnostic `ML-G2-3-5-6-10` still has stale explanatory
text in `compiler/nucleor_s1_compiler.nr` / `bootstrap/nucleor_s1_seed.ll`
saying tensor_nd matmul/transpose are missing. This helper slice
deliberately kept compiler/bin/bootstrap untouched; main integration
should refresh that diagnostic text during the next compiler/seed
workflow.
