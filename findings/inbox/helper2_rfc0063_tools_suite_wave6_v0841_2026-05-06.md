# Helper2 RFC-0063 Tools-Suite Wave 6 v0841

Date: 2026-05-06

Branch: `fix/helper2-rfc0063-tools-suite-wave6-v0841`
Base: `origin/main` at `4fa86e027a08f5e83dbc6e931dd42e1234894a21`
Merge-base: `4fa86e027a08f5e83dbc6e931dd42e1234894a21`
HEAD: branch tip containing this report; exact pushed SHA is recorded in the final handoff.

## Worktree Note

The assigned worktree `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_helper2_wave5_v0840` was checked out to other local lanes while this work was in progress and had unrelated uncommitted edits in `compiler/nucleor_s1_compiler.nr`, `stdlib/rods/quantum.nr`, and related test files. To avoid mixing lanes, Helper2 Wave 6 was isolated in:

`C:\Users\JoeWe\Desktop\Nucleor_OSS_helper2_rfc0063_wave6_v0841_clean`

Only Helper2's two in-progress files were transferred into the clean worktree. The original shared worktree was restored for those two files only; unrelated local edits were left untouched.

## Scope Completed

Queue 16 Wave 6 continued RFC-0063 Phase 2.0 duplicate deletion/import after Wave 5. This batch moved 29 byte-identical non-parser helpers from `compiler/nucleor_tools_suite.nr` into `compiler/nucleor_rfc0063_shared_wave1.nr`, which is already imported by the tools-suite. The s1 compiler remains the raw canonical copy.

No parser functions, SIG_MATCH_BODY_DIFFERS helpers, SIG_DIFFERS helpers, R05 effects files, ROBO-7 files, Linux package/R06 tooling, `bin/`, `bootstrap/`, performance baselines, Rust dependencies, or Python helpers were changed.

## Selected Helpers

All selected helpers were confirmed as `IDENTICAL` by the refreshed `tools/audit_dup_fns_report.csv` before editing:

- `smap_hash`
- `smap_new_cap`
- `smap_slots`
- `smap_slot_used`
- `smap_slot_key`
- `smap_slot_val`
- `smap_find_slot`
- `smap_grow`
- `smap_set`
- `smap_get`
- `diag_new`
- `diag_add`
- `diag_count`
- `diag_get`
- `struct_find`
- `struct_find_type`
- `struct_field_idx`
- `struct_field_type`
- `enum_find`
- `is_copy_type`
- `sig_find`
- `sig_plist`
- `sig_rtype`
- `sig_is_extern`
- `byte_to_line`
- `find_in_source`
- `path_overlaps`
- `source_line`
- `line_has_unit_literal`

`smap_grow` was included in the dedicated `smap_*` batch. It is growth-sensitive, but the duplicate audit confirmed it is byte-identical in s1 and tools-suite, and the focused build, drift, ABI, and perf gates passed after the move.

Skipped candidates: none from Queue 16's listed candidate pools. `smap_has` and `smap_clone` were intentionally not moved because they were not part of the Wave 6 requested `smap_*` list.

## Duplicate Audit

Before Wave 6:

- s1 fns: 834
- tools fns: 593
- duplicate names: 314
- IDENTICAL: 135
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

After Wave 6:

- s1 fns: 834
- tools fns: 565
- duplicate names: 285
- IDENTICAL: 106
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

Net effect: 29 additional raw tools-suite duplicate helper definitions removed, with only IDENTICAL candidates touched.

## Files Changed

- `compiler/nucleor_rfc0063_shared_wave1.nr`
- `compiler/nucleor_tools_suite.nr`
- `tools/audit_dup_fns_report.csv`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `findings/inbox/helper2_rfc0063_tools_suite_wave6_v0841_2026-05-06.md`

## Validation

`.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache`

- PASS
- Source: `compiler\nucleor_tools_suite.nr`
- Functions: 716
- DCE: 39 of 716 fns elided as unreachable
- Emitted: `target/nucleor_tools.ll`
- Compiled: `target\nucleor_tools.exe`

`.\bin\nucleor.exe check examples\01_hello.nr --no-cache`

- PASS
- Parsed: 1 top-level item
- Checkers: ownership,type,source,taint,effect
- Result: OK, no diagnostics

`.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave6_build_strict --no-cache`

- PASS
- Emitted: `target/_rfc0063_wave6_build_strict.ll`
- Compiled: `target\_rfc0063_wave6_build_strict.exe`

`.\bin\nucleor.exe abi examples\01_hello.nr`

- PASS
- ABI version: `c-v1-imports-only`
- Extern imports: none

`.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry "$env:TEMP\nucleor-rfc0063-wave6-registry" --dry-run`

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

- PASS
- `cold=3.73s`, `hot=0.43s`
- `cold_tree=361/400MB`, `cold_compiler=346/350MB`, `hot_tree=70/128MB`, `hot_compiler=55/64MB`

## Recommended Wave 7 Candidates

Start Queue 17 only after Wave 6 is integrated into `origin/main`; do not stack on the unintegrated Wave 6 branch. Recommended IDENTICAL-only candidates from the remaining pool:

- Source/string helpers: `str_starts_with`, `source_line`-adjacent callers still remaining in the pool, `find_in_source`-adjacent callers if still duplicated after integration.
- Small profiling/type env helpers: `tprof_start`, `tprof_mark`, `tprof_dump`, `tenv_set`, `tenv_get`, `unit_dim`, `type_stmt_value`.
- Module-record and content helpers: `module_record_add`, `module_records_serialize`, `module_records_validate`, `resolve_source`, `content_hash`, `compiler_backend_label`, `compiler_identity`.

Keep parser-adjacent helpers deferred until the parser-unification lane intentionally absorbs duplicate-name collision risk. The first `SIG_MATCH_BODY_DIFFERS` review wave should wait until the IDENTICAL pool is smaller or drained.

## Main Integration Guidance

Main should run normal integration drift/perf checks after merge. Helper2 did not change `bin/`, `bootstrap/`, compiler seeds, broad verify gates, or performance baselines, so a helper-side self-host fixed-point or full verify was not required for this branch.

## Main Integration Review

Integrated on `integrate/helper2-wave6-v0842` as commit `c73f5f3f`
after cherry-picking Helper2's branch tip onto current `origin/main`
(`4fa86e02`).

Integration validation:

- `.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache` PASS.
- `.\bin\nucleor.exe check examples\01_hello.nr --no-cache` PASS.
- `.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave6_build_strict_integration --no-cache` PASS.
- `.\bin\nucleor.exe abi examples\01_hello.nr` PASS.
- `.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry "$env:TEMP\nucleor-rfc0063-wave6-integration-registry" --dry-run` PASS.
- `bash tools/check_compiler_drift.sh` PASS with existing RFC-0063 parser warnings only.
- `bash tools/check_rod_void_abi.sh` PASS.
- `git diff --check HEAD~1..HEAD` PASS.
- `pwsh -NoProfile -File tools\check_perf_regression.ps1` PASS: cold `3.8s`, hot `0.42s`, cold tree `362MB`, cold compiler `348MB`.

Perf note: the cold compiler RSS is now close to the 350MB compiler ceiling,
so further compiler-hot or tools-suite waves should avoid extra full-source
walks and continue running the perf gate.
