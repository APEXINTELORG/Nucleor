# Helper2 RFC-0063 tools-suite duplicate deletion/import Wave 8

Date: 2026-05-07
Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_helper2_rfc0063_wave6_v0841_clean`
Branch: `fix/helper2-rfc0063-tools-suite-wave8-v0842`
Base / merge-base: `45500baa8998da06dde49ae679af7ab3ecbb2341`
Working HEAD at validation before local commit: `45500baa8998da06dde49ae679af7ab3ecbb2341`

## Scope

Wave 8 continued RFC-0063 duplicate deletion from current `origin/main`, after Wave 7 was content-landed on main as `15f7e392`. This wave moved another IDENTICAL-only, non-parser batch into `compiler/nucleor_rfc0063_shared_wave1.nr`, kept `compiler/nucleor_s1_compiler.nr` canonical, and removed the raw duplicate definitions from `compiler/nucleor_tools_suite.nr`.

No Python helpers, Rust work, compiler binary, bootstrap, verify-gate, perf-baseline, R05, ROBO-7, RT, quantum, package/R06, or parser body edits were made.

## Moved Helpers

29 byte-identical helpers were moved:

`opt_cse_block`, `hex_digit`, `hex_byte`, `emit_arith`, `find_extern_idx`, `emit_extern_call`, `emit_str_constants`, `is_ptr_type`, `tensor_builtin_method_name`, `type_is_shared_ref`, `type_is_ref`, `sendable_source_has_actor_decl`, `sendable_source_has_spawn_call`, `sendable_is_bare_ident`, `sendable_second_type`, `sendable_type_has_impl`, `sendable_binding_type`, `sendable_find_matching_paren`, `sendable_find_top_comma`, `sendable_find_matching_brace`, `sendable_actor_fields`, `enforce_sendable_actor_fields`, `enforce_sendable_contracts`, `expr_borrow_key`, `expr_root_name`, `expr_escape_root`, `check_stmts`, `builtin_rtype_format_string_i64`, `builtin_rtype_format_string_str`.

## Audit Counts

Before Wave 8 from current main:

- duplicate names: 252
- `IDENTICAL`: 73
- `SIG_MATCH_BODY_DIFFERS`: 163
- `SIG_DIFFERS`: 16

After Wave 8:

- duplicate names: 223
- `IDENTICAL`: 44
- `SIG_MATCH_BODY_DIFFERS`: 163
- `SIG_DIFFERS`: 16
- s1 function count: 840
- tools raw function count: 503

The refreshed report is `tools/audit_dup_fns_report.csv`.

## Remaining IDENTICAL Rows

Remaining IDENTICAL candidates after Wave 8:

`str_from_int`, `str_is_digits`, `tok_type`, `tok_val`, `is_digit`, `tok_at`, `tok_type_at`, `tok_val_at`, `node_add`, `node_kind`, `node_field`, `list_len`, `list_get`, `pr_pos`, `pr_val`, `pk`, `pkv`, `parse_args`, `skip_bracket_list`, `skip_compile_time_param_default`, `ct_param_type_is_unsigned`, `ct_param_default_is_negative_literal`, `skip_angle_group`, `skip_where_clause`, `parse_match_binding_block`, `mk_passthrough_block_expr`, `parse_passthrough_block_expr`, `parse_wrapped_block_expr`, `parse_mul`, `parse_add`, `parse_eq`, `parse_and_expr`, `parse_or_expr`, `parse_pipe_expr`, `parse_expr`, `parse_type_alias_decl`, `parse_return_stmt`, `parse_stmts`, `has_main_decl`, `remove_main_decl`, `lower_if_expr_branch`, `lower_stmts`, `resolve_source`, `close_synthesize_fn`.

## Skipped Candidates

Skipped parser or parser-adjacent candidates despite IDENTICAL classification: `parse_args`, `skip_bracket_list`, `skip_compile_time_param_default`, `skip_angle_group`, `skip_where_clause`, `parse_match_binding_block`, `mk_passthrough_block_expr`, `parse_passthrough_block_expr`, `parse_wrapped_block_expr`, `parse_mul`, `parse_add`, `parse_eq`, `parse_and_expr`, `parse_or_expr`, `parse_pipe_expr`, `parse_expr`, `parse_type_alias_decl`, `parse_return_stmt`, `parse_stmts`.

Skipped token/list/node primitives for a dedicated parser-infrastructure wave: `str_from_int`, `str_is_digits`, `tok_type`, `tok_val`, `is_digit`, `tok_at`, `tok_type_at`, `tok_val_at`, `node_add`, `node_kind`, `node_field`, `list_len`, `list_get`, `pr_pos`, `pr_val`, `pk`, `pkv`.

Skipped larger remaining compiler pipeline helpers for a later targeted wave: `lower_if_expr_branch`, `lower_stmts`, `resolve_source`, `close_synthesize_fn`, `has_main_decl`, `remove_main_decl`.

## Validation

Passed from current `origin/main` base `45500baa8998da06dde49ae679af7ab3ecbb2341`:

- `.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache`
- `.\bin\nucleor.exe build tools\audit_dup_fns.nr -o audit_dup_fns --no-cache`
- `.\target\audit_dup_fns.exe`
- `.\bin\nucleor.exe check examples\01_hello.nr --no-cache`
- `.\bin\nucleor.exe build-strict examples\01_hello.nr -o _rfc0063_wave8_build_strict --no-cache`
- `.\bin\nucleor.exe abi examples\01_hello.nr`
- `.\bin\nucleor.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry $env:TEMP\nucleor-rfc0063-wave8-registry --dry-run`
- `.\bin\nucleor.exe build tools\gen_rod_manifest.nr -o gen_rod_manifest`
- `.\target\gen_rod_manifest.exe`
- `bash tools/check_compiler_drift.sh`
- `bash tools/check_rod_void_abi.sh`
- `git diff --check`
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`

Notes:

- `bash tools/check_compiler_drift.sh` passed with the known RFC-0063 parser drift warnings for `parse_match_stmt`, `parse_stmt`, and `parse_expr`.
- The current main base made `docs/rfcs/rod_manifest.toml` stale due to new `stdlib/rods/quantum.nr` content. The manifest was regenerated with `tools\gen_rod_manifest.nr`: total rods `254`, fn definitions `3174`, LOC `13780`.
- `git diff --check` exited 0 with the existing line-ending warning for `tools/audit_dup_fns_report.csv`.
- Perf gate passed after final rebase: `cold=3.42s` max 4s, `hot=0.43s` max 1s, `cold_tree=363/400MB`, `cold_compiler=349/350MB`, `hot_tree=70/128MB`, `hot_compiler=55/64MB`.

## Recommendation

One or two IDENTICAL waves remain before the body-diff review starts. The next wave should be explicit about whether token/list/node primitives are allowed, because most remaining IDENTICAL rows are parser infrastructure or parser bodies. If allowed, take a coherent parser-infrastructure batch first: `str_from_int`, `str_is_digits`, `tok_type`, `tok_val`, `is_digit`, `tok_at`, `tok_type_at`, `tok_val_at`, `node_add`, `node_kind`, `node_field`, `list_len`, `list_get`, `pr_pos`, `pr_val`, `pk`, `pkv`, plus the compile-time parameter helpers if the branch owner accepts parser-adjacent utilities.

After the IDENTICAL pool is drained, start `SIG_MATCH_BODY_DIFFERS` with low-review, non-parser rows: `ctr_next`, `mk2`-`mk6`, `pr`, `module_graph_cache_id`, `compile_file`, `ir_inst`, `tprof_enabled`, `type_is_mut_ref`, `is_tainted_type`, `taint_inner_type`, `type_is_unit`, `cmd_accepts_source`, and `cmd_allows_output_name`.
