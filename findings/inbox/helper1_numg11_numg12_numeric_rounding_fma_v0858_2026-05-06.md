# Helper1 Finding - NUM-G11 / NUM-G12 Numeric Rounding + FMA

**Date:** 2026-05-06
**Branch:** `fix/helper1-qm6-mps-joint-prob-v0831`
**Status:** ready for integration

## Summary

`numeric.nr` now has a user-facing IEEE-754 rounding/FMA surface:

- stable rounding mode IDs:
  `n_rounding_nearest`, `n_rounding_downward`,
  `n_rounding_upward`, `n_rounding_toward_zero`;
- `n_get_rounding_mode()` and `n_set_rounding_mode(mode)`;
- `n_f64_next_up(x)` and `n_f64_next_down(x)`;
- scalar `n_f64_mul_add(a, b, c)` and `n_f32_mul_add(a, b, c)`.

The implementation lives in new `stdlib/rods/numeric_rt.c`.

## Evidence

`tests/features/numeric_rounding_fma_smoke.nr` locks:

- get/set round-trip for all four rounding modes;
- invalid mode returns `-1`;
- next-up/next-down move around 1.0 in the correct direction;
- f64/f32 fused multiply-add helpers compute `2*3+4 = 10`.

## Residual Gap

This is a runtime rod surface, not compiler intrinsic lowering.
`n_f64_mul_add` / `n_f32_mul_add` use C `fma` / `fmaf`; future
compiler work can lower source-level `mul_add` directly to LLVM FMA
intrinsics. The rounding API exposes process rounding-mode control,
so callers should restore the previous mode after scoped use.
