# Helper1 R05 requires row enforcement v0844

Branch: `fix/helper1-r05-requires-row-enforcement-v0844`

Start base: `45500baa8998da06dde49ae679af7ab3ecbb2341`

Rebased base: `c46ba610be025ac8d0e3b4b0d8842bd233fb1ee1`

## Scope

Queue A from `_parallel_agent_assignment_v0844_post_qm7_pkg_r06_2026-05-07.md`.

`origin/main` already contained direct same-file requires-row propagation through
`enforce_requires_direct_calls`. The remaining high-value standalone gap was that
functions declaring `requires [...]` did not check their own body against known
builtin effects, and did not walk un-rowed helper bodies for those effects.

## Changes

- Added `requires_body_direct_missing(...)` for the minimum direct builtin
  surface: print-family / `print_int` / `putchar`, `getchar`, `channel`, and
  direct `Vec::new` / `Box::new` allocation constructors.
- Added `requires_transitive_missing(...)` for bounded depth=3 same-file helper
  propagation through un-rowed helper functions.
- Wired both into `enforce_requires_direct_calls` while preserving the existing
  direct rowed-callee checks.
- Added two negative fixtures and one positive smoke:
  - `tests/err/err_requires_row_builtin_io_mismatch.nr`
  - `tests/err/err_requires_row_transitive_builtin_io.nr`
  - `tests/features/requires_row_transitive_builtin_ok.nr`

## Helper validation

- PASS: `.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _helper1_r05_requires_rebased_syntax_v0844 --no-cache --no-link`
- PASS: `bash tools/check_self_host_md5.sh`
  - fixed-point and seed md5: `022de4f1ee4096348c4f53f0aca97311`
- PASS: positive fixtures build and run:
  - `tests/features/requires_row_transitive_builtin_ok.nr`
  - `tests/features/effect_requires_direct_ok.nr`
  - `tests/features/requires_row_clean_smoke.nr`
- PASS: negative fixtures exit nonzero and emit `EFF-001`:
  - `tests/err/err_requires_row_builtin_io_mismatch.nr`
  - `tests/err/err_requires_row_transitive_builtin_io.nr`
  - `tests/err/err_requires_row_direct_call.nr`
  - `tests/err/err_effect_requires_direct.nr`
- PASS: `bash tools/check_compiler_drift.sh`
  - Existing RFC-0063 parser divergence warnings only.
- PASS: `bash -n tools/verify.sh`
- PASS: `bash -n tools/verify_fast.sh`
- PASS: `git diff --check`
- PASS: `pwsh -NoProfile -File tools\check_perf_regression.ps1`
  - `cold=3.63s`, `hot=0.41s`
  - `cold_tree=348MB`, `cold_compiler=333MB`
  - `hot_tree=70MB`, `hot_compiler=55MB`

## Main integration note

Integrated after `origin/main` advanced through R05 consolidation and RFC-0063
Wave 9. The helper's stale compiler-source shape was adapted to the current
unified R05 function table (`collect_fn_table`, `lookup_fn_row_in_table`,
`lookup_fn_body_in_table`) instead of reintroducing the older separate
`collect_requires_effect_rows` / `collect_fn_bodies` walks. Promoted binary and
seed were regenerated from the integrated compiler source.
