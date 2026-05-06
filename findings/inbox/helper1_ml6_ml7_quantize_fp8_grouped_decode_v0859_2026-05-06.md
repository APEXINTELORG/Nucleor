# Helper1 ML-6 / ML-7 Quantize Decode + FP8/Grouped Closure v0859

## Summary

Closed the stdlib/runtime/test/doc portion of the quantize gaps that were still
disclosure-only:

- FP8 now exposes `quant_fp8_decode`, `quant_fp8_gemv`, and `quant_fp8_dot`.
- INT8 now exposes `quant_int8_decode`.
- Ternary now exposes `quant_ternary_decode`.
- Grouped signed-Q4 now exposes `quant_grouped_encode`,
  `quant_grouped_decode`, and `quant_grouped_gemv` with per-group scales.
- `quant_op_supported(...)` and `quantize_limitations()` now report the new
  surface truthfully.

## Evidence

Focused fixture:

- `tests/features/quantize_decode_grouped_fp8_smoke.nr`

The fixture checks callable decode/inference behavior instead of only link
presence:

- INT8 per-row decode approximates the source matrix.
- Ternary decode returns the absmean-scaled {-1,0,+1} representation.
- FP8 decode, GEMV, and dot operate on the existing scaled signed-byte runtime
  representation.
- Grouped signed-Q4 decode and GEMV operate over per-group scales.
- The support table and limitations text reflect the new surface.

## Residual Gaps

- FP8 remains the runtime's simplified signed-byte scaled representation rather
  than true IEEE-style E4M3 bit encoding.
- Per-scheme error-bound documentation remains open.
- `quant_free` remains a coarse legacy opaque-handle free helper; this slice did
  not alter the handle ownership contract.

## Files Changed

- `stdlib/runtime/quantize_rt.c`
- `stdlib/rods/quantize.nr`
- `tests/features/quantize_decode_grouped_fp8_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`
