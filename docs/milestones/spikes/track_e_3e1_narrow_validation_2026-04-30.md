# Track E Spike: i8/i16/i32 Strict-Intrinsic Validation

Date: 2026-04-30
Branch: `v05-spike-3e1-narrow-validation`
Base: Track D `v05-spike-3span2`
Includes: Track B compiler intrinsic patch plus Track E precedence/fixture patch

## Workflow Note

This branch is intentionally isolated for the other workflow. It has not been pushed to `main`.

The Track E patch clarifies strict-arithmetic precedence:

1. Explicit source modes win first:
   - `wrapping { ... }` emits wrapping arithmetic and must not trap under strict envs.
   - `saturating { ... }` emits saturating helpers and must not be preempted by strict intrinsics.
2. Outside explicit modes, `NUCLEOR_INT_STRICT_INTRIN=1` wins over `NUCLEOR_INT_STRICT_ARITH=1` for signed add/sub/mul.
3. `NUCLEOR_INT_STRICT_ARITH=1` remains the legacy helper path when `NUCLEOR_INT_STRICT_INTRIN` is off.

## Code Shape

- `compiler/nucleor_s1_compiler.nr`
  - Adds `arith_width_helper_name(...)` for narrow saturating helper selection.
  - Gates the LLVM overflow-intrinsic path behind `__arith_mode <= 0`.
  - Sets `__arith_mode=1` for `wrapping { ... }`, matching existing `__arith_mode=2` saturating handling.
- `tools/verify.sh`
  - Adds one Track E gate step for signed narrow strict intrinsics and explicit-mode env precedence.
- `tests/fixtures/strict_intrin_*.nr`
  - Adds i8 add, i16 sub, i32 mul overflow fixtures plus explicit-mode precedence coverage.

## Expected Targeted Proof

The new verify step checks:

- `@llvm.sadd.with.overflow.i8`
- `@llvm.ssub.with.overflow.i16`
- `@llvm.smul.with.overflow.i32`
- Runtime overflow exits nonzero under `NUCLEOR_INT_STRICT_INTRIN=1`.
- `wrapping { ... }` and `saturating { ... }` still run under both strict env vars enabled.

## Validation Status

Completed in this spike worktree:

- Capped compiler smoke rebuild: PASS, `520 MB / 1024 MB`, `4.738s`.
- Capped compiler seed rebuild after promoting `bin/nucleor.exe`: PASS, `542 MB / 1024 MB`, `5.139s`.
- Targeted Track E fixtures under `NUCLEOR_INT_STRICT_INTRIN=1` and `NUCLEOR_INT_STRICT_ARITH=1`: PASS.
  - `strict_intrin_i8_add_overflow.nr`: emitted `llvm.sadd.with.overflow.i8`, runtime rc `1`, build peak `151 MB / 1024 MB`.
  - `strict_intrin_i16_sub_overflow.nr`: emitted `llvm.ssub.with.overflow.i16`, runtime rc `1`, build peak `156 MB / 1024 MB`.
  - `strict_intrin_i32_mul_overflow.nr`: emitted `llvm.smul.with.overflow.i32`, runtime rc `1`, build peak `134 MB / 1024 MB`.
  - `strict_intrin_explicit_modes_precedence.nr`: emitted `__nucleor_saturating_add_i64`, runtime rc `0`, build peak `134 MB / 1024 MB`.

Still required by the workflow that integrates or rebases the spike:

- full `tools/verify.sh` env-off result
- full `tools/verify.sh` env-on result
