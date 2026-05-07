# Helper1 R05 transitive effects residual v0844

Branch: `fix/helper1-r05-transitive-effects-residual-v0844`

Base: `c46ba610be025ac8d0e3b4b0d8842bd233fb1ee1`

## Scope

Queue B from `_parallel_agent_assignment_v0844_post_qm7_pkg_r06_2026-05-07.md`.

The safe extension available on fresh `origin/main` was the same-file
`restricts [...]` helper-chain depth budget. Cross-module propagation still
needs a larger module/effect symbol table and is not faked here.

## Changes

- Raised the bounded same-file `restricts_transitive_check(...)` budget from
  depth=3 to depth=8.
- Preserved the lazy perf shape: the function-body table is still built only
  when a real code-position `restricts [` block is present.
- Updated the EFF-G123 disclosure text so command output now says depth=8 and
  "beyond depth=8" instead of the stale depth=3 wording.
- Added one negative depth=8 fixture and one clean positive control:
  - `tests/err/err_restricts_block_transitive_depth8_chain.nr`
  - `tests/features/restricts_block_transitive_depth8_clean_smoke.nr`

## Helper validation

- PASS: `.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _helper1_r05_transitive_syntax_v0844 --no-cache --no-link`
- PASS: `bash tools/check_self_host_md5.sh`
  - fixed-point and seed md5: `1fe1a084bb686659a1e457f3619452ca`
- PASS: positive fixtures build and run:
  - `tests/features/restricts_block_transitive_depth8_clean_smoke.nr`
  - `tests/features/restricts_block_transitive_clean_smoke.nr`
- PASS: negative fixtures exit nonzero and emit `EFF-003`:
  - `tests/err/err_restricts_block_transitive_depth8_chain.nr`
  - `tests/err/err_restricts_block_transitive_deep_chain.nr`
  - `tests/err/err_restricts_block_transitive_unrowed_io.nr`
- PASS: `bash tools/check_compiler_drift.sh`
  - Existing RFC-0063 parser divergence warnings only.
- PASS: `bash -n tools/verify.sh`
- PASS: `bash -n tools/verify_fast.sh`
- PASS: `git diff --check`
- PASS: `pwsh -NoProfile -File tools\check_perf_regression.ps1`
  - Sample 1: `cold=3.76s`, `hot=0.42s`, `cold_tree=363MB`, `cold_compiler=349MB`
  - Sample 2: `cold=3.70s`, `hot=0.41s`, `cold_tree=362MB`, `cold_compiler=348MB`

## Main integration note

The source-side depth=8 implementation was already superseded by the R05
consolidation landed on main at `5ed65ffe`; this integration kept the useful
depth-8 positive/negative fixtures and aligned the EFF-G123 disclosure text.
