# Helper2 RFC-0063 Tools-Suite Wave 4 v0840

Date: 2026-05-06

Branch: `fix/helper2-rfc0063-tools-suite-wave4-v0840`
Base: `origin/main` at `d3bbd9d4d7bcf0e8f6bea6ea5c9d594fbf379acb`
Merge-base: `d3bbd9d4d7bcf0e8f6bea6ea5c9d594fbf379acb`
HEAD: branch tip containing this report; exact pushed SHA is recorded in the final handoff.

## Scope Completed

Queue 14 Wave 4 continued RFC-0063 Phase 2.0 duplicate deletion/import after Wave 3. This batch moved 25 byte-identical cache/path/host helpers from the raw tools-suite file into `compiler/nucleor_rfc0063_shared_wave1.nr`, which is already imported by `compiler/nucleor_tools_suite.nr`. The s1 compiler remains the canonical raw copy.

No parser functions, SIG_MATCH_BODY_DIFFERS helpers, SIG_DIFFERS helpers, Cloud Linux package/R06 tooling, R05 effects, Helper1 ROBO-7 files, `bin/`, `bootstrap/`, performance baselines, Rust dependencies, or Python helpers were changed.

## Selected Helpers

All selected helpers were confirmed as `IDENTICAL` by `tools/audit_dup_fns_report.csv` before editing:

- `target_root_name`
- `cache_v2_strict_intrin_flag`
- `cache_v2_dbc_flag`
- `cache_v2_prefix`
- `cache_v2_dir`
- `cache_v2_ll_path`
- `cache_v2_meta_dir`
- `cache_v2_size_mb`
- `cache_v2_stats_enabled`
- `cache_v2_print_stats`
- `cache_v2_meta_json`
- `host_is_windows`
- `host_exe_suffix`
- `host_target_path_sep`
- `host_null_redirect`
- `host_remove_file_quiet`
- `write_ll_artifact_if_needed`
- `extract_dir`
- `path_is_absolute`
- `trim_trailing_sep`
- `parent_dir`
- `strip_ext`
- `basename`
- `is_output_name_char`
- `normalize_output_name`

## Duplicate Audit

Before Wave 4:

- s1 fns: 825
- tools fns: 638
- duplicate names: 359
- IDENTICAL: 180
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

After Wave 4:

- s1 fns: 825
- tools fns: 613
- duplicate names: 334
- IDENTICAL: 155
- SIG_MATCH_BODY_DIFFERS: 163
- SIG_DIFFERS: 16

Net effect: 25 additional raw tools-suite duplicate helper definitions removed, with only IDENTICAL candidates touched.

## Files Changed

- `compiler/nucleor_rfc0063_shared_wave1.nr`
- `compiler/nucleor_tools_suite.nr`
- `tools/audit_dup_fns_report.csv`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/RFC-0063-production-readiness-roadmap.md`
- `findings/inbox/helper2_rfc0063_tools_suite_wave4_v0840_2026-05-06.md`

## Validation

`.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache`

- PASS
- Source: `compiler\nucleor_tools_suite.nr`
- Functions: 715
- DCE: 39 of 715 fns elided as unreachable
- Emitted: `target/nucleor_tools.ll`
- Compiled: `target\nucleor_tools.exe`

`.\bin\nucleor.exe check examples\01_hello.nr --no-cache`

- PASS
- Parsed: 1 top-level item
- Checkers: ownership,type,source,taint,effect
- Result: OK, no diagnostics

`.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave4_build_strict --no-cache`

- PASS
- Emitted: `target/_rfc0063_wave4_build_strict.ll`
- Compiled: `target\_rfc0063_wave4_build_strict.exe`

`.\bin\nucleor.exe abi examples\01_hello.nr`

- PASS
- ABI version: `c-v1-imports-only`
- Extern imports: none

`.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry "$env:TEMP\nucleor-rfc0063-wave4-registry" --dry-run`

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

- First sample: FAIL on hot compiler RSS only, `66MB vs max 64MB`.
- Allowed rerun: PASS
- Passing sample: `cold=3.34s`, `hot=0.4s`, `cold_tree=340/400MB`, `cold_compiler=326/350MB`, `hot_tree=69/128MB`, `hot_compiler=55/64MB`.

## Recommended Wave 5 Candidates

Prefer another small IDENTICAL-only batch after main integration:

- Atomic-ordering cluster: `is_atomic_ordered_builtin`, `atomic_tail_order_llvm`, `atomic_cmpxchg_success_order_llvm`, `atomic_cmpxchg_failure_order_llvm`, `atomic_rmw_op_llvm`, `emit_atomic_ordered_call`.
- Small map/container cluster: `cmap_new`, `cmap_set`, `cmap_get`, `cmap_has`, `ctr_new`, `sym_new`, `sym_set`, `sym_clone`.
- `smap_*` should stay a dedicated batch if it includes `smap_grow`, because growth behavior is more sensitive than simple accessors.
- Parser-adjacent token/list helpers should remain deferred until the parser-unification lane is ready to absorb collision risk deliberately.

## Main Integration Guidance

Main should run normal integration drift/perf checks after merge. Helper2 did not change `bin/`, `bootstrap/`, compiler seeds, broad verify gates, or performance baselines, so a helper-side self-host fixed-point or full verify was not required for this branch.
