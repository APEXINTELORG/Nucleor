# Helper2 RFC-0063 tools-suite duplicate deletion/import Wave 7

Date: 2026-05-07
Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_helper2_rfc0063_wave6_v0841_clean`
Branch: `fix/helper2-rfc0063-tools-suite-wave7-v0842`
Base / merge-base: `3ce1ef1139af76ce5007d2bd710b6e919f245903`
Working HEAD at validation before local commit: `3ce1ef1139af76ce5007d2bd710b6e919f245903`

## Scope

Wave 7 continued RFC-0063 duplicate deletion from current `origin/main`, after Wave 6 was content-landed on main by cherry-pick. This wave moved another IDENTICAL-only, non-parser batch into `compiler/nucleor_rfc0063_shared_wave1.nr`, kept `compiler/nucleor_s1_compiler.nr` canonical, and removed the raw duplicate definitions from `compiler/nucleor_tools_suite.nr`.

No Python helpers, Rust work, compiler binary, bootstrap, verify-gate, perf-baseline, R05, ROBO-7, RT, quantum, package/R06, or parser body edits were made.

## Moved Helpers

33 byte-identical helpers were moved:

`str_starts_with`, `is_ws`, `is_alpha`, `is_alnum`, `tprof_start`, `tprof_mark`, `tprof_dump`, `type_diag`, `tenv_set`, `tenv_get`, `unit_dim`, `type_stmt_value`, `source_has_scope_escape_ref_binding`, `capture_has_name`, `capture_param_has`, `build_mode_name`, `print_phase_time`, `collect_native_directives`, `path_exists`, `module_record_add`, `module_records_serialize`, `module_records_validate`, `fmt_trim_ws`, `fmt_strip_outer_quotes`, `priv_string_vec_contains`, `priv_string_vec_push_unique`, `priv_lookup_origin`, `content_hash`, `compiler_backend_label`, `compiler_identity`, `cli_is_flag`, `run_zen_command`, `run_mco_command`.

## Audit Counts

Before Wave 7 from current main:

- duplicate names: 285
- `IDENTICAL`: 106
- `SIG_MATCH_BODY_DIFFERS`: 163
- `SIG_DIFFERS`: 16

After Wave 7 on rebased current main:

- duplicate names: 252
- `IDENTICAL`: 73
- `SIG_MATCH_BODY_DIFFERS`: 163
- `SIG_DIFFERS`: 16
- s1 function count: 840
- tools raw function count: 532

The refreshed report is `tools/audit_dup_fns_report.csv`.

## Skipped Candidates

Skipped parser or parser-adjacent candidates despite IDENTICAL classification: `parse_args`, `skip_bracket_list`, `skip_compile_time_param_default`, `skip_angle_group`, `skip_where_clause`, `parse_match_binding_block`, `mk_passthrough_block_expr`, `parse_passthrough_block_expr`, `parse_wrapped_block_expr`, `parse_mul`, `parse_add`, `parse_eq`, `parse_and_expr`, `parse_or_expr`, `parse_pipe_expr`, `parse_expr`, `parse_type_alias_decl`, `parse_return_stmt`, `parse_stmts`.

Skipped already-landed Wave 6 source/path candidates: `source_line`, `find_in_source`, `byte_to_line`, `line_has_unit_literal`, `path_overlaps`.

Skipped large or semantically dense remaining IDENTICAL candidates for a later dedicated wave: `lower_if_expr_branch`, `lower_stmts`, `resolve_source`, `close_synthesize_fn`, `check_stmts`, `expr_borrow_key`, `expr_root_name`, `expr_escape_root`, `sendable_*`, codegen helpers, and token/list/node primitives.

## Validation

Passed after rebase onto `origin/main` at `3ce1ef1139af76ce5007d2bd710b6e919f245903`:

- `.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache`
- `.\bin\nucleor.exe build tools\audit_dup_fns.nr -o audit_dup_fns --no-cache`
- `.\target\audit_dup_fns.exe`
- `.\bin\nucleor.exe check examples\01_hello.nr --no-cache`
- `.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave7_build_strict --no-cache`
- `.\bin\nucleor.exe abi examples\01_hello.nr`
- `.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry $env:TEMP\nucleor-rfc0063-wave7-registry --dry-run`
- `bash tools/check_compiler_drift.sh`
- `bash tools/check_rod_void_abi.sh`
- `git diff --check`
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`

Notes:

- `bash tools/check_compiler_drift.sh` passed with the known RFC-0063 parser drift warnings for `parse_match_stmt`, `parse_stmt`, and `parse_expr`.
- `git diff --check` exited 0 with the existing CRLF warning for `tools/audit_dup_fns_report.csv`.
- Perf gate passed after host load settled: `cold=3.56s` max 4s, `hot=0.41s` max 1s, `cold_tree=363/400MB`, `cold_compiler=348/350MB`, `hot_tree=70/128MB`, `hot_compiler=55/64MB`.

## Recommendation

Continue draining the remaining 73 IDENTICAL rows before starting body-diff work. The next IDENTICAL wave should either take the safe token/list/node primitive group as a coherent parser-infrastructure batch or take the non-parser codegen/type/ref group, but should avoid mixing those with `parse_*` bodies.

Once the IDENTICAL pool is drained, the first `SIG_MATCH_BODY_DIFFERS` review wave should start with small, non-parser rows where review cost is low: `ctr_next`, `mk2`-`mk6`, `pr`, `module_graph_cache_id`, `compile_file`, `ir_inst`, `tprof_enabled`, `type_is_mut_ref`, `is_tainted_type`, `taint_inner_type`, `type_is_unit`, `cmd_accepts_source`, and `cmd_allows_output_name`. Defer parser rows and ownership/type-env rows with larger body deltas until a dedicated semantic review wave.
