# Numerics Matrix Test Manifest

This directory holds the **T1.1 maximalist numerics refactor**
test matrix. Each subdirectory groups tests by the phase of the
plan (`Desktop/Nucleor_T1_Numerics_Maximalist_Plan.md`) that
should turn its tests green.

## Workflow

- Tests in this tree are NOT picked up by the standard verify
  gate (`tools/verify.ps1`) because verify enumerates only the
  top level of each `tests/{lang,attrs,runtime,rods,features}/`
  directory.
- Run them via the dedicated runner:
  - PowerShell: `pwsh tools/run_numerics_matrix.ps1`
  - Bash:       `bash  tools/run_numerics_matrix.sh`
- The runner builds + runs each `.nr` and reports
  `<phase> <test> PASS | FAIL | BUILD_ERROR`.
- At Phase 0 (v0.2.307) the entire matrix is expected to FAIL
  (or BUILD_ERROR for tests that exercise not-yet-parseable
  syntax). That's the point — the matrix is the contract for
  the work ahead.
- Each subsequent phase makes its subdirectory's tests pass
  without regressing earlier subdirectories.

## Phase coverage

| Subdir         | Phase | Topic                                          | Tests at v0.2.307 |
|----------------|-------|------------------------------------------------|-------------------|
| `p1_intarith/` | 1     | Width-aware integer arithmetic + comparisons   | 24                |
| `p2_literals/` | 2     | Suffix literals + overflow at compile time     | 6                 |
| `p3_layout/`   | 3     | Width-correct alloca + struct layout           | 3                 |
| `p4_cast/`     | 4     | `as` cast operator full matrix                 | 8                 |
| `p5_float/`    | 5     | Native float arithmetic                        | 4                 |
| `p6_bitwise/`  | 6     | Bitwise + shift at width                       | 4                 |
| `p7_overflow/` | 7     | wrap/trap/saturate modes + intrinsics          | 4                 |
| `p8_vec/`      | 8     | `Vec<T>` monomorphization byte-packing         | 3                 |
| `p9_ffi/`      | 9     | FFI ABI: narrow-width extern fn + gen-headers  | 1                 |
| `p11_format/`  | 11    | Width-correct formatting                       | 2                 |

**Total at v0.2.307 (Phase 0 baseline): 56 tests.**
**Status: 31 PASS / 9 FAIL / 16 BUILD_ERROR.**

**At v0.2.310 (Phase 3c): 58 tests (2 added for i32/u32 wrap).**
**Status: 43 PASS / 7 FAIL / 8 BUILD_ERROR.**

(Many tests already pass at v0.2.306 because narrow types compile
and arithmetic is correct WITHIN i64 range. The 9 FAIL + 16
BUILD_ERROR are the actual gap surface — width-overflow wrap,
native float arithmetic, narrow bitwise, overflow modes, generic
`Vec<T>` syntax, and width-correct print_*. Each subsequent phase
flips its subdir's failures to PASS.)

The matrix grows as each phase lands additional cases. Final
target ~250 tests across all phases.

## Test convention

Each `.nr` test file:
- Has `fn main() -> i32 { ... }` returning `0` on success,
  non-zero on failure, mirroring the existing `tests/lang/*.nr`
  pattern.
- Prints `OK <test_name>` on success.
- Prints `FAIL: <reason>` on each individual sub-assertion that
  fails, then returns 1.
- Self-contained — no `mod` imports, no helpers.
