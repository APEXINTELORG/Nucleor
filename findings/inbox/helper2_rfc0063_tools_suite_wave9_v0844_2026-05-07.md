# Helper2 RFC-0063 tools-suite Wave 9 body-diff triage

Date: 2026-05-07
Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_helper2_rfc0063_wave6_v0841_clean`
Branch: `fix/helper2-rfc0063-tools-suite-wave9-v0844`
Base / merge-base: `c46ba610be025ac8d0e3b4b0d8842bd233fb1ee1`
Working HEAD at validation before local commit: `c46ba610be025ac8d0e3b4b0d8842bd233fb1ee1`

## Scope

Queue B started after Wave 8 was integrated to `origin/main` as `c46ba610`. This wave triaged the `SIG_MATCH_BODY_DIFFERS` bucket and implemented the first mechanically safe bucket: functions whose tools-suite and s1 executable bodies normalize identically after removing comments and whitespace. The moved functions are same-signature, same executable text, and differed only by comments or formatting.

No Python helpers, Rust work, compiler binary, bootstrap, verify-gate, perf-baseline, R05, ROBO-7, RT, quantum, package/R06, or parser body edits were made.

## Implemented Bucket

19 normalized-identical `SIG_MATCH_BODY_DIFFERS` helpers were moved from `compiler/nucleor_tools_suite.nr` into `compiler/nucleor_rfc0063_shared_wave1.nr`:

`expand_format_macros`, `priv_apply_if_opted_in`, `emit_cmp`, `str_eq_at`, `llvm_clang_path`, `own_merge_moved`, `fmt_build_concat_chain`, `narrow_via_as`, `priv_build_global_registry`, `priv_extract_fn_decl_info`, `close_parse_body_end`, `skip_compile_time_params`, `fmt_split_args`, `priv_collect_private_fn_names`, `priv_lift_link_errors`, `classify_kw`, `close_parse_arg_list`, `expand_async_await`, `emit_builtin_call`.

## Audit Counts

Before Wave 9 from current main:

- duplicate names: 223
- `IDENTICAL`: 44
- `SIG_MATCH_BODY_DIFFERS`: 163
- `SIG_DIFFERS`: 16
- s1 function count: 844 after R05 consolidation landed on main
- tools raw function count: 503

After Wave 9:

- duplicate names: 204
- `IDENTICAL`: 44
- `SIG_MATCH_BODY_DIFFERS`: 144
- `SIG_DIFFERS`: 16
- s1 function count: 844 after R05 consolidation landed on main
- tools raw function count: 484

The refreshed report is `tools/audit_dup_fns_report.csv`.

## Remaining Body-Diff Triage

Remaining `SIG_MATCH_BODY_DIFFERS` rows after Wave 9, grouped for follow-on review:

- Parser or parser infrastructure, 29: `mk_list`, `mk2`, `mk3`, `mk4`, `mk5`, `mk6`, `parse_cmp`, `parse_const_decl`, `parse_enum_decl`, `parse_extern_fn`, `parse_fn_decl`, `parse_for_stmt`, `parse_generic_params`, `parse_if`, `parse_impl_block`, `parse_let`, `parse_postfix`, `parse_primary`, `parse_program`, `parse_stmt`, `parse_struct_decl`, `parse_struct_init`, `parse_trait_decl`, `parse_type`, `parse_unary`, `parse_while_stmt`, `source_box_binding_type`, `tok_new`, `tok_to_ir`.
- Diagnostics or error text, 3: `diag_add_ex`, `diag_emit_text`, `run_explain_command`.
- Tool-mode CLI/cache/package, 32: `build_cache_key`, `cache_v2_canonical_flags`, `cache_v2_json_escape`, `cmd_accepts_source`, `cmd_allows_output_name`, `compile_file_mode`, `compiler_version_label`, `fmt_build_expansion`, `fmt_conversion_for_spec`, `manifest_entry_path`, `module_graph_cache_id`, `priv_mangle_private_fns`, `priv_string_vec_contains_at`, `resolve_import_path`, `resolve_source_with_records`, `resolve_toolchain_path`, `run_abi_command`, `run_bootstrap_command`, `run_clean_command`, `run_evidence_command`, `run_graph_command`, `run_impact_command`, `run_install_command`, `run_lock_command`, `run_perf_command`, `run_profile_command`, `run_publish_command`, `run_query_command`, `run_registry_command`, `run_sage_command`, `run_stage_dump_command`, `run_summary_command`.
- Compiler codegen/lowering, 26: `builtin_rtype`, `compile_file`, `emit_externs`, `emit_fn`, `emit_inst`, `emit_user_externs`, `escape_llvm_str`, `expand_actor_decl_keyword`, `expand_async_strip_keyword`, `expand_closures`, `expand_deadline`, `expand_format_macros_with_src`, `ir_block_new`, `ir_call_ex`, `ir_fn_new`, `ir_fn_ptr`, `ir_indirect_call`, `ir_inst`, `is_ptr_arg`, `is_ptr_ret`, `is_void_ret`, `lower_expr`, `lower_stmt`, `nr_type_to_llvm`, `type_is_mut_ref`, `type_is_unit`.
- Ownership/type/effects, 19: `closure_collect_capture_expr`, `closure_collect_capture_stmt`, `enforce_sendable_spawn_name`, `is_tainted_type`, `own_get_mutable`, `own_put_i`, `own_put_s`, `own_restore`, `own_snapshot`, `sendable_actor_decl_name_at`, `sendable_actor_vars`, `sendable_collect_actor_names`, `sendable_type_forced_not`, `sendable_type_ok`, `sym_get`, `taint_inner_type`, `type_base_name`, `type_check_program`, `type_dynamic_helper`.
- Generic helpers requiring small review, 35: `check_expr`, `check_stmt`, `close_is_arg_position_char`, `ctr_next`, `dl_extract_int_value`, `dl_parse_fn_signature`, `enum_populate_sym`, `expect_tok`, `expr_struct_type`, `extract_directives`, `find_linecol_in_source`, `get_rt_name`, `host_stack_link_flag`, `iter_method_for_vec`, `lex`, `line_contains_text`, `link_native_module`, `load_resolved_source_bundle`, `main`, `match_bind_payloads_typed`, `opt_dce_block`, `opt_dead_store_block`, `opt_fn`, `opt_fold_block`, `opt_prop_block`, `pr`, `preflight_source_check`, `print_help`, `str_from_i64`, `str_to_int`, `strip_spaces`, `text_contains`, `tprof_enabled`, `tprof_new`, `types_compatible`.

## Validation

Passed:

- `.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache`
- `.\bin\nucleor.exe build tools\audit_dup_fns.nr -o audit_dup_fns --no-cache`
- `.\target\audit_dup_fns.exe`
- `bash tools/check_compiler_drift.sh`
- `bash tools/check_rod_void_abi.sh`
- `git diff --check`
- `pwsh -NoProfile -File tools\check_perf_regression.ps1`

Notes:

- `bash tools/check_compiler_drift.sh` passed with the known RFC-0063 parser drift warnings for `parse_match_stmt`, `parse_stmt`, and `parse_expr`.
- `git diff --check` exited 0 with line-ending warnings for `compiler/nucleor_rfc0063_shared_wave1.nr`, `compiler/nucleor_tools_suite.nr`, and `tools/audit_dup_fns_report.csv`.
- Perf gate passed: `cold=3.66s` max 4s, `hot=0.43s` max 1s, `cold_tree=362/400MB`, `cold_compiler=347/350MB`, `hot_tree=70/128MB`, `hot_compiler=55/64MB`.

## Main integration note

Integrated after `origin/main` advanced to `5ed65ffe` with the promoted
R05 effect-row consolidation. The Wave 9 code/docs applied cleanly; the
only integration adjustment was refreshing the s1 function-count notes from
840 to 844. Duplicate totals remain the Wave 9 totals: 204 duplicate names,
44 `IDENTICAL`, 144 `SIG_MATCH_BODY_DIFFERS`, and 16 `SIG_DIFFERS`.

## Residual Blockers

The remaining 144 same-signature body-diff rows are not safe to import blindly. Next Wave 9 continuation should take one reviewed semantic bucket at a time:

- Start with generic small-review helpers that have small line counts and no parser/codegen coupling: `ctr_next`, `pr`, `tprof_enabled`, `tprof_new`, `strip_spaces`, `text_contains`, `line_contains_text`, `find_linecol_in_source`.
- Keep parser rows isolated. Parser bodies still have known RFC-0063 drift and should not be normalized opportunistically.
- Keep drift-gated raw-source tables local unless `tools/check_compiler_drift.sh` is taught to account for shared imports. `is_ptr_ret` and `compiler_version_label` normalized identically but had to be restored to `compiler/nucleor_tools_suite.nr` because the current drift gate scans the raw tools-suite body and reported missing table/version data when those functions were imported.
- Keep tool-mode command rows isolated because some tools-suite behavior is intentionally CLI-specific.
- Keep `SIG_DIFFERS` untouched until all same-signature review buckets have explicit adapter decisions.
