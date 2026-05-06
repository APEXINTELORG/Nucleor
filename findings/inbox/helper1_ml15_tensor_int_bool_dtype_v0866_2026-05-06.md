# Helper1 Finding - ML-15 Tensor Int/Bool Dtype Surfaces (v0866)

## Summary

ML-15 P2a is now partially closed for `tensor_nd`:

- Added explicit int tensor constructors:
  - `tensor_new_int_2d(rows, cols)`
  - `tensor_new_int_nd(shape)`
- Added explicit bool/mask tensor constructors:
  - `tensor_new_bool_2d(rows, cols)`
  - `tensor_new_bool_nd(shape)`
- Added runtime dtype code tracking and rod predicates:
  - `tensor_dtype_code`
  - `tensor_dtype_int`
  - `tensor_dtype_bool`
  - `tensor_is_int`
  - `tensor_is_bool`
- Added typed flat accessors:
  - `tensor_set_int_flat` / `tensor_get_int_flat`
  - `tensor_set_bool_flat` / `tensor_get_bool_flat`

## Evidence

Focused fixture:

- `tests/features/tensor_int_bool_dtype_smoke.nr`

Validated commands:

```powershell
git diff --check
.\bin\nucleor.exe build tests\features\tensor_int_bool_dtype_smoke.nr -o helper1_tensor_int_bool_dtype --no-cache
.\target\helper1_tensor_int_bool_dtype.exe
bash tools/verify.sh --only "test features/tensor_int_bool_dtype_smoke"
bash tools/verify.sh --only "test features/tensor_shape_dtype_smoke"
bash tools/verify.sh --only "test features/tensor_nd_smoke"
bash tools/verify.sh --only "test features/tensor_nd_matmul_transpose_smoke"
bash tools/verify.sh --only "test features/tensor_nd_permute_smoke"
```

The fixture checks:

- Int tensor dtype string/code/predicates, shape metadata, and signed integer round-trip.
- Bool tensor dtype string/code/predicates and mask normalization from nonzero values to `1`.
- Legacy tensor dtype behavior remains `i64`.
- `tensor_limitations()` names the new int/bool surface.

## Files Changed

- `stdlib/runtime/tensor3d_rt.c`
- `stdlib/rods/tensor_nd.nr`
- `tests/features/tensor_int_bool_dtype_smoke.nr`
- `docs/rfcs/gap-analyses/Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Residual

This is a conservative stdlib/runtime P2a. Tensor backing storage remains double-based for ABI compatibility. True f32/f64 named dtype surfaces, compiler-visible tensor dtype/shape checking, and broader mixed-precision kernel dispatch remain open.

## Diagnostic Caveat

The compiler still emits stale overbroad `info[ML-G2-3-5-6-10]` text that says some now-shipped tensor/ML primitives are missing. That is a compiler diagnostic text update, not part of this stdlib-only slice.
