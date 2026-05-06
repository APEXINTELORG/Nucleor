# Helper1 Finding - ML-2 / ML-3 tensor_nd Matmul + Transpose

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

ML-2 and the rank-2 portion of ML-3 are closed on the tensor_nd rod.

New API:

- `tensor_new_2d(rows, cols)` creates rank-2 tensor handles.
- `tensor_matmul(a, b)` computes rank-2 `A @ B` and returns `0` on
  null, non-2D, or incompatible shapes.
- `tensor_transpose(h)` returns rank-2 `A^T` and returns `0` for
  null or non-2D handles.

## Evidence

`tests/features/tensor_nd_matmul_transpose_smoke.nr` locks:

- rank/shape/total metadata for `tensor_new_2d(2, 3)`;
- exact `2x3 @ 3x2` product values `[58, 64; 139, 154]`;
- `tensor_transpose` shape `3x2` and representative values;
- incompatible-shape matmul returns `0`;
- `tensor_limitations()` names `tensor_matmul` and `tensor_transpose`.

## Residual Gap

This does not ship general `tensor_permute`, multi-axis transpose, or
typed tensor dtypes. `tensor_limitations()` now names those residual
boundaries directly.

Compiler audit diagnostic `ML-G2-3-5-6-10` still has stale explanatory
text in `compiler/nucleor_s1_compiler.nr` / `bootstrap/nucleor_s1_seed.ll`
saying 2D matmul and transpose are missing. This helper slice deliberately
kept compiler/bin/bootstrap untouched; main integration should refresh that
diagnostic text during the next compiler/seed workflow.
