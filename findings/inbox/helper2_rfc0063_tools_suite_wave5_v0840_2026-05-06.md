# Helper2 RFC-0063 Tools-Suite Wave 5 v0840

Date: 2026-05-06

Branch: `fix/helper2-rfc0063-tools-suite-wave5-v0840`
Original base after helper rebase: `origin/main` at `218117d6bcbf2845fecc8f0974a626513a2dbddc`
Original merge-base: `218117d6bcbf2845fecc8f0974a626513a2dbddc`
HEAD: branch tip containing this report; exact pushed SHA is recorded in the final handoff.

## Integration Review

Codex reviewed and cherry-picked this wave after `origin/main` had
advanced to `74303c3d` with the ROBO-7 repair. The wave remained
tools-suite-only plus docs/report/duplicate-audit CSV; it did not touch
`bin/`, `bootstrap/`, R05 effects, or ROBO-7 compiler surfaces.

Final integration validation passed on top of `74303c3d`: tools-suite
build, `check`, `build-strict`, `abi`, publish dry-run, compiler drift,
rod void ABI, whitespace, and perf. The perf sample was `cold=3.45s`,
`hot=0.38s`, `cold_tree=357MB`, `cold_compiler=343MB`, `hot_tree=69MB`,
and `hot_compiler=55MB`.

## Scope Completed

Queue 15 Wave 5 continued RFC-0063 Phase 2.0 duplicate deletion/import after Wave 4. The branch was initially created from `origin/main` at `0dd3bbacec675e9c5256abb80ec3229af7b08c95`, then rebased onto `origin/main` at `218117d6bcbf2845fecc8f0974a626513a2dbddc` after main advanced with the R05 effects integration.

This batch moved 20 byte-identical non-parser helpers from `compiler/nucleor_tools_suite.nr` into `compiler/nucleor_rfc0063_shared_wave1.nr`, which is already imported by the tools-suite. The s1 compiler remains the raw canonical copy.

No parser functions, SIG_MATCH_BODY_DIFFERS helpers, SIG_DIFFERS helpers, `smap_*` growth-sensitive helpers, Cloud Linux package/R06 tooling, R05 effects files, Helper1 ROBO-7 files, `bin/`, `bootstrap/`, performance baselines, Rust dependencies, or Python helpers were changed.

## Selected Helpers

All selected helpers were confirmed as `IDENTICAL` by `tools/audit_dup_fns_report.csv` before editing:

- `is_atomic_ordered_builtin`
- `atomic_tail_order_llvm`
- `atomic_cmpxchg_success_order_llvm`
- `atomic_cmpxchg_failure_order_llvm`
- `atomic_rmw_op_llvm`
- `emit_atomic_ordered_call`
- `block_has_term`
- `cmap_new`
- `cmap_set`
- `cmap_get`
- `cmap_has`
- `ctr_new`
- `sym_new`
- `sym_set`
- `sym_clone`
- `lx_new`
- `lx_reg`
- `lx_blk`
- `trait_impl_register`
- `trait_impl_find`

## Duplicate Audit

Before Wave 5, from the rebased `origin/main` CSV:

- duplicate names: 334
- IDENTICAL: 155
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

After Wave 5 on the helper base:

- s1 fns: 830
- tools fns: 593
- duplicate names: 314
- IDENTICAL: 135
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

Net effect: 20 additional raw tools-suite duplicate helper definitions removed, with only IDENTICAL candidates touched.

After integration on the ROBO-7-updated main, the current CSV still
reports 314 duplicate names: 135 `IDENTICAL`, 163
`SIG_MATCH_BODY_DIFFERS`, and 16 `SIG_DIFFERS`.

## Files Changed

- `compiler/nucleor_rfc0063_shared_wave1.nr`
- `compiler/nucleor_tools_suite.nr`
- `tools/audit_dup_fns_report.csv`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `findings/inbox/helper2_rfc0063_tools_suite_wave5_v0840_2026-05-06.md`

## Validation

The helper commands below were run after rebasing onto
`218117d6bcbf2845fecc8f0974a626513a2dbddc`; Codex reran the same
focused integration class on top of `74303c3d`.

`.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache`

- PASS
- Integration rerun PASS: source `compiler\nucleor_tools_suite.nr`,
  715 functions, DCE `39 of 715`, emitted `target/nucleor_tools.ll`,
  compiled `target\nucleor_tools.exe`.

`.\bin\nucleor.exe check examples\01_hello.nr --no-cache`

- PASS
- Parsed: 1 top-level item
- Checkers: ownership,type,source,taint,effect
- Integration rerun PASS: current output is `OK — no diagnostics`.

`.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave5_build_strict --no-cache`

- PASS
- Emitted: `target/_rfc0063_wave5_build_strict.ll`
- Compiled: `target\_rfc0063_wave5_build_strict.exe`

`.\bin\nucleor.exe abi examples\01_hello.nr`

- PASS
- ABI version: `c-v1-imports-only`
- Extern imports: none

`.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry "$env:TEMP\nucleor-rfc0063-wave5-registry" --dry-run`

- PASS
- Dry run: no files copied, no registry metadata written, no checksums written, no signatures created
- Package: `foo`
- Version: `0.1.0`

`bash tools/check_compiler_drift.sh`

- PASS
- Known RFC-0063 parser warnings remain for `parse_match_stmt`, `parse_stmt`, and `parse_expr`.
- Hard checks passed: tools-suite ABI tables, promoted compiler version, manifests, release docs, duplicate audit CSV, CHANGELOG coverage, compiler version labels, and no `pub fn` privatization markers.

`bash tools/check_rod_void_abi.sh`

- PASS
- `OK: rod void ABI clean (355 C void nuc_* definitions, 1272 non-void rod externs checked)`

`git diff --check`

- PASS
- Warning only: `tools/audit_dup_fns_report.csv` LF will be replaced by CRLF the next time Git touches it.

`pwsh -NoProfile -File tools\check_perf_regression.ps1`

- First rebased sample: FAIL on hot compiler RSS only, `66MB vs max 64MB`.
- Allowed rerun: PASS
- Integration rerun PASS: `cold=3.45s`, `hot=0.38s`,
  `cold_tree=357/400MB`, `cold_compiler=343/350MB`,
  `hot_tree=69/128MB`, `hot_compiler=55/64MB`.

## Recommended Wave 6 Candidates

Prefer one of these IDENTICAL-only batches after main integration:

- Dedicated `smap_*` batch: `smap_hash`, `smap_new_cap`, `smap_slots`, `smap_slot_used`, `smap_slot_key`, `smap_slot_val`, `smap_find_slot`, `smap_grow`, `smap_set`, `smap_get`. If `smap_grow` is included, keep the batch small and call out that it is growth-sensitive but byte-identical.
- Small diagnostics/record helpers: `diag_new`, `diag_add`, `diag_count`, `diag_get`, `struct_find`, `struct_find_type`, `struct_field_idx`, `struct_field_type`, `enum_find`, `is_copy_type`.
- String/source utility helpers: `byte_to_line`, `find_in_source`, `str_starts_with`, `path_overlaps`, `source_line`, `line_has_unit_literal`.

Keep parser-adjacent helpers deferred until the parser-unification lane intentionally absorbs duplicate-name collision risk.

## Main Integration Guidance

Main should run normal integration drift/perf checks after merge. Helper2 did not change `bin/`, `bootstrap/`, compiler seeds, broad verify gates, or performance baselines, so a helper-side self-host fixed-point or full verify was not required for this branch.
