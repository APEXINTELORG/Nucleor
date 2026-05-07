# Cloud Claude2 effects delta integration review v0841

Date: 2026-05-07
Integration branch: `integrate/cloud2-effects-delta-v0841`
Source branch reviewed: `origin/fix/cloud-claude2-effects-compiler-slice-v0840`

## Decision

The cloud2 branch was not merged wholesale. It was based behind current
`origin/main` and carried stale generated artifacts plus overlapping R05
compiler work that main had already landed through local Claude.

Integrated only the unique, fixture-backed delta:

- `restricts [alloc] { Vec::new() }` now emits `EFF-003` through a small
  body-level builtin check in the existing `enforce_restricts_block_effects`
  pass.
- `restricts_block_disjoint_call.nr` locks the positive case where a
  block restricted to `net` calls a same-file callee declared
  `requires [io.read]`.

Not integrated:

- The stale `bootstrap/nucleor_s1_seed.ll` and `bin/nucleor.exe` from the
  older cloud2 base.
- The alternate whole `enforce_restricts_blocks` implementation, because
  main already has the local-Claude first slice and the broad replacement
  would reintroduce version and overlap risk.
- Unfixture-backed builtin claims for ambient/schedule expansion.

## Follow-up

R05 still needs the planned bounded same-file transitive restricts/requires
slice, cross-module rows, methods/closures/higher-order rows, and fuller
RFC-0033 row subtyping.

## Validation

- `.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o target\nucleor_s1_check --no-cache` PASS.
- `.\target\nucleor_s1_check.exe build tests\err\err_restricts_block_alloc.nr ...` failed as expected with `error[EFF-003]`.
- `.\target\nucleor_s1_check.exe build tests\err\err_restricts_block_builtin_io.nr ...` still failed as expected with `error[EFF-003]`.
- `restricts_block_disjoint_call.nr` and `restricts_block_clean_smoke.nr` built and ran with exit code 0.
- `bash tools/check_self_host_md5.sh` PASS, md5 `0c6f1085786c041830943203b415d2d5`.
- `bash tools/check_compiler_drift.sh` PASS with the existing RFC-0063 parser-divergence warnings only.
- `bash tools/check_rod_void_abi.sh` PASS.
- `git diff --check` PASS.
- `pwsh -NoProfile -File tools\check_perf_regression.ps1` PASS: cold `3.51s`, hot `0.45s`, cold tree `360MB`, cold compiler `346MB`.
