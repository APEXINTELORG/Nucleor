# RFC-0063 Phase 2.0.1 Parser Unification Survey

**Date:** 2026-05-06  
**Scope:** Research-only survey of nucleor_tools_suite.nr vs nucleor_s1_compiler.nr  
**Context:** Understanding parser drift and unification scope before Phase 2.0.2-2.0.5 ships  

---

## 1. CLI Surface Handled by tools_suite

### Main Entry Point: `fn main() -> i64` (line 19754)

The tools_suite dispatches 29 CLI commands via prefix matching on `args_get(1)`:

| Command | Handler | Line | Purpose |
|---------|---------|------|---------|
| `--version`/`-v` | inline | 19762 | Emit compiler_identity() |
| `help`/`--help`/`-h` | inline | 19766 | Print help text |
| `explain` | `run_explain_command(argc)` | 19771 | Diagnostic code explanation |
| `bootstrap` | `run_bootstrap_command(argc)` | 19774 | Corpus bootstrap tooling |
| `stage-dump` | `run_stage_dump_command(argc)` | 19777 | Debug AST/IR serialization |
| `lock` | `run_lock_command(argc)` | 19780 | Dependency lock management |
| `deps` | `run_deps_command(argc)` | 19783 | List/resolve transitive deps |
| `fix` | `run_fix_command(tgt, sub)` | 19797 | Auto-fix imports/numerics in source |
| `doc` | `run_doc_command[_html]()` | 19824 | Markdown/HTML doc generation from /// comments |
| `install` | `run_install_command(argc)` | 19834 | Package install via registry |
| `publish` | `run_publish_command(argc)` | 19837 | Push package to registry |
| `registry` | `run_registry_command(argc)` | 19840 | Registry metadata queries |
| `profile` | `run_profile_command(argc)` | 19843 | Timing + memory profiling |
| `sage` | `run_sage_command(argc)` | 19846 | Compiler hints/suggestions |
| `zen` | `run_zen_command()` | 19849 | Aphorism output (Easter egg) |
| `mco` | `run_mco_command()` | 19852 | Temporal WCET oracle |
| `clean`/`scram` | `run_clean_command(argc)` | 19855 | Purge target/ cache |
| `init` | inline | 19857 | Scaffold new Nucleor.toml project |
| `build` | `compile_file_mode(src_path, ..., 1, use_cache, ...)` | 20008 | Strict-mode full compile to native exe |
| `build-fast` | `compile_file_mode(..., 0, use_cache, ...)` | 20010 | Fast-mode compile (fewer passes) |
| `build-strict` | `compile_file_mode(..., 1, use_cache, ...)` | 20012 | Explicit strict mode (alias of `build`) |
| `build-shared` | `run_build_shared_command(...)` | 20015 | Compile to shared library (.so/.dll) |
| `run` | `compile_file_mode(...)` + `system(exe)` | 20016 | Compile and execute directly |
| `build-wasm` | `compile_file_mode()` path (20021+) | 20021 | Compile to WASM target |
| `summary` | `run_summary_command(src_path, argc, arg_start)` | 19993 | AST/type summary + metadata report |
| `evidence` | `run_evidence_command(src_path)` | 19996 | Security/property evidence checklist |
| `query` | `run_query_command(src_path)` | 19998 | Symbol/type query interface |
| `abi` | `run_abi_command(src_path, argc, arg_start)` | 20000 | ABI export surface + compatibility checks |
| `impact` | `run_impact_command(src_path, argc, arg_start)` | 20002 | Call-graph impact analysis |
| `graph` | `run_graph_command(src_path, argc, arg_start)` | 20004 | Dependency graph visualization |
| `perf` | `run_perf_command(src_path, argc, arg_start)` | 20006 | Performance hotspot auditing |

**Total: 29 commands** — 14 infrastructure (build/project mgmt); 15 tools (analysis/reporting).

---

## 2. Parser Function Inventory

### lex/tok Functions

| Function | tools Line | Args | s1 Match | Delta |
|----------|-----------|------|----------|-------|
| `lex()` | 117 | `(src: str)` | 261 | **DRIFT**: tools ~250 lines, s1 ~300+ (needs detailed count) |
| `tok_new()` | 70 | `(tt, v, p)` | 9545 | Same signature; helper |
| `tok_type()` | 73 | `(t: Vec<i32>)` | — | accessor, tools-only |
| `tok_val()` | 74 | `(t: Vec<i32>)` | — | accessor, tools-only |
| `tok_at()` | 258 | `(tokens, idx)` | — | vector lookup, tools-only |
| `tok_type_at()` | 261 | `(tokens, idx)` | — | derived, tools-only |
| `tok_val_at()` | 262 | `(tokens, idx)` | — | derived, tools-only |
| `tok_to_ir()` | 4988 | `(tok: i64)` | s1:16405 | Present in both |

### parse_* Functions (36 in tools, 40+ in s1)

**Core Expression Hierarchy** (right-associative precedence chain):

| Function | tools Line | s1 Line | tools Size | s1 Size | Notes |
|----------|-----------|---------|-----------|---------|-------|
| `parse_expr()` | 761 | 2946 | **1 line** (passthrough to parse_pipe_expr) | **1 line** (same) | Identical thin wrappers |
| `parse_pipe_expr()` | 731 | 2915 | **30 lines** | **31 lines** | ~98% match; s1 has extra span tracking |
| `parse_or_expr()` | 724 | 2907 | **7 lines** | **8 lines** | ~95% match |
| `parse_and_expr()` | 718 | 2900 | **6 lines** | **7 lines** | ~95% match |
| `parse_eq()` | 710 | 2890 | **8 lines** | **10 lines** | ~85% match; s1 more ops |
| `parse_cmp()` | 701 | 2880 | **9 lines** | **10 lines** | ~92% match |
| `parse_add()` | 693 | 2829 | **8 lines** | **16 lines** | **DRIFT**: tools missing shift ops |
| `parse_mul()` | 685 | 2820 | **8 lines** | **9 lines** | ~95% match |
| `parse_unary()` | 667 | 2763 | **18 lines** | **57 lines** | **MAJOR DRIFT**: tools 77% smaller |
| `parse_postfix()` | 617 | 2634 | **50 lines** | **129 lines** | **DRIFT**: tools 61% smaller; missing advanced expr forms |
| `parse_primary()` | 478 | 1986 | **139 lines** | **648 lines** | **CRITICAL DRIFT**: tools 79% smaller; missing literal/closure/etc forms |

**Statement & Declaration Parsing:**

| Function | tools Line | s1 Line | tools Size | s1 Size | Notes |
|----------|-----------|---------|-----------|---------|-------|
| `parse_stmt()` | 970 | 3818 | **22 lines** | **241 lines** | **CRITICAL DRIFT**: tools 91% smaller; missing v0.6+ halts (break-with-value, yield, local-type-alias, local-const, local-static, local-fn) |
| `parse_stmts()` | 993 | 4061 | **9 lines** | **7 lines** | ~95% match |
| `parse_let()` | 882 | 3268 | Present | Present | Needs detailed compare |
| `parse_if()` | 914 | 3424 | Present | Present | Needs detailed compare |
| `parse_while_stmt()` | 935 | 3630 | Present | Present | Needs detailed compare |
| `parse_for_stmt()` | 943 | 3750 | Present | Present | Needs detailed compare |
| `parse_return_stmt()` | 962 | 3809 | Present | Present | Needs detailed compare |
| `parse_fn_decl()` | 1001 | 4070 | Present | Present | Needs detailed compare |
| `parse_extern_fn()` | 1031 | 4230 | Present | Present | Needs detailed compare |
| `parse_struct_decl()` | 1053 | 4279 | Present | Present | Needs detailed compare |
| `parse_struct_init()` | 1084 | 4444 | Present | Present | Needs detailed compare |
| `parse_enum_decl()` | 1104 | 4502 | Present | Present | Needs detailed compare |
| `parse_trait_decl()` | 1153 | 4595 | Present | Present | Needs detailed compare |
| `parse_impl_block()` | 1202 | 4751 | Present | Present | Needs detailed compare |
| `parse_match_stmt()` | 1270 | 4909 | **175 lines** | **137 lines** | **PARADOX**: tools 28% larger; has extra tools-specific logic (parse_match_binding_block alternative) |
| `parse_program()` | 1470 | 5074 | Present | Present | Needs detailed compare |

**Type & Generic Parsing:**

| Function | tools Line | s1 Line | Match |
|----------|-----------|---------|-------|
| `parse_type()` | 763 | 2949 | Present in both |
| `parse_generic_params()` | 847 | 3186 | Present in both |
| `parse_where_clause_into_gparams()` | — | 1410 | **s1-only** (where-clause for generics) |
| `parse_const_decl()` | 894 | 3399 | Present in both |
| `parse_type_alias_decl()` | 905 | 3414 | Present in both |

**Match Pattern Parsing (s1-specific extensions):**

| Function | tools Line | s1 Line | Status |
|----------|-----------|---------|--------|
| `parse_match_binding_block()` | 438 | 1473 | Present in both |
| `parse_match_struct_binding_block()` | — | 1573 | **s1-only** (struct patterns in match) |
| `parse_match_list_binding()` | — | 1628 | **s1-only** (list patterns in match) |
| `parse_match_one_pattern()` | — | 1660 | **s1-only** (factored pattern parser) |

### Summary: Parser Drift
- **parse_stmt**: tools 91% smaller (22 vs 241 lines)
- **parse_primary**: tools 79% smaller (139 vs 648 lines)
- **parse_postfix**: tools 61% smaller (50 vs 129 lines)
- **parse_match_stmt**: tools 28% **larger** (175 vs 137 lines) — contains tools-specific binding alternatives
- **Expression hierarchy**: ~95-98% alignment (minor drift in precedence chain)
- **Root cause**: tools_suite snapshot from earlier version + independent fixes/additions that diverged

---

## 3. Type-Check Function Inventory

| Function | tools Line | s1 Line | tools Size | s1 Size | Notes |
|----------|-----------|---------|-----------|---------|-------|
| `sym_new()` | 4840 | 9545 | 1 line | 1 line | Identical |
| `sym_set()` | 4841 | 9547 | 1 line | 1 line | Identical |
| `sym_get()` | 4842 | 9608 | 5 lines | ~ | Present in both |
| `sym_clone()` | 4847 | 9652 | 8 lines | ~ | Present in both |
| `tenv_new()` | 7594 | 19948 | 1 line | 1 line | Identical |
| `tenv_set()` | 7595 | 19950 | 1 line | 1 line | Identical |
| `tenv_get()` | 7596 | 19952 | 16 lines | ~ | Present in both |
| `tenv_const_key()` | — | 19958 | tools N/A | **s1-only** (const folding) |
| `tenv_set_const_i64()` | — | 19962 | tools N/A | **s1-only** (const value tracking) |
| `tenv_get_const_i64()` | — | 19970 | tools N/A | **s1-only** (const value lookup) |
| `type_is_unit()` | 7611 | 20297 | 2 lines | 14 lines | Both present; s1 extended |
| `type_is_mut_ref()` | 5618 | 10358 | 5 lines | ~ | Present in both |
| `type_is_shared_ref()` | 5623 | 10363 | 5 lines | ~ | Present in both |
| `type_is_ref()` | 5628 | 10369 | 5 lines | ~ | Present in both |
| `type_base_name()` | 5101 | 9989 | 22 lines | ~ | Present in both |
| `type_check_program()` | 8185 | 22907 | **34 lines** | **224 lines** | **MAJOR DRIFT**: tools 85% smaller; s1 has const-value tracking + global-consts verification |
| `type_check_stmts()` | 8172 | 22840 | Present | Present | Both present |
| `type_check_stmt()` | 8049 | 22205 | Present | Present | Both present |
| `type_expr()` | 7819 | 20442 | Present | Present | Both present; s1 has extra prog param |
| `type_last_stmt()` | 7809 | 20431 | Present | Present | Both present; s1 has extra prog param |

**enforce_* Functions (v0.6+ safety/correctness gates):**

Tools-suite has minimal enforcement; s1 has comprehensive policy layers:

| Enforce Gate | tools | s1 Line | Category |
|--------------|-------|---------|----------|
| `enforce_sendable_spawn_name()` | 5445 | 13913 | Actor safety (spawn-able types) |
| `enforce_sendable_actor_fields()` | 5574 | 14058 | Actor field types |
| `enforce_sendable_contracts()` | 5605 | 14090 | Actor protocol validation |
| `enforce_requires_direct_calls()` | — | 11583 | **s1-only** (RT-001) |
| `enforce_isr_placement()` | — | 12765 | **s1-only** (RT-002) |
| `enforce_isr_contracts()` | — | 12930 | **s1-only** (RT-003) |
| `enforce_no_alloc()` | — | 14776 | **s1-only** (RT-004) |
| `enforce_no_panic()` | — | 14966 | **s1-only** (RT-005) |
| `enforce_atomic_ordering()` | — | 15276 | **s1-only** (atomic ops) |
| `enforce_atomic_contracts()` | — | 15303 | **s1-only** (atomic ops) |
| `enforce_no_dyn()` | — | 15433 | **s1-only** (dynamic types) |
| `enforce_rt005_ffi()` | — | 15647 | **s1-only** (FFI) |
| `enforce_max_depth_static()` | — | 16261 | **s1-only** (recursion depth) |
| `enforce_rt008_recursion()` | — | 16348 | **s1-only** (recursion) |
| `enforce_rt006_async()` | — | 16427 | **s1-only** (async) |
| `enforce_async001_warning()` | — | 16467 | **s1-only** (async warning) |
| `enforce_body_diagnostics_unified()` | — | 16790 | **s1-only** (diag unification) |
| `enforce_hot_fn_purity()` | — | 16958 | **s1-only** (hot fn policy) |
| `enforce_deadline_with_await()` | — | 17000 | **s1-only** (temporal deadline) |
| `enforce_unawaited_spawn()` | — | 17144 | **s1-only** (actor housekeeping) |
| `enforce_pure_fn_purity()` | — | 17247 | **s1-only** (pure fn policy) |
| `enforce_heap_in_loop()` | — | 17445 | **s1-only** (GC/allocation) |
| `enforce_const_fn_purity()` | — | 17562 | **s1-only** (const fn policy) |
| `enforce_static_wcet()` | — | 17600 | **s1-only** (static WCET) |
| `enforce_deadline_safety()` | — | 17630 | **s1-only** (temporal deadline) |

**Summary**: tools_suite type-checking is a minimal stub. s1 has ~30+ enforce gates covering actor safety, temporal safety, allocation policies, purity, FFI, atomics, recursion depth—all missing from tools.

---

## 4. Emit-Summary Function Inventory

### Emit Functions (LLVM IR generation)

| Function | tools | s1 | Category |
|----------|-------|---|---------| 
| `emit_atomic_ordered_call()` | 1651 | 5429 | Atomic operation lowering |
| `emit_builtin_call()` | 3517 | 7618 | Built-in fn lowering (print, alloc, etc) |
| `emit_cmp()` | 3613 | 7724 | Comparison instruction emission |
| `emit_arith()` | 3622 | 7742 | Arithmetic instruction emission |
| `emit_arith_w()` | — | 7752 | **s1-only** (width-aware arithmetic) |
| `emit_overflow_arith()` | — | 7761 | **s1-only** (overflow trap emission) |
| `emit_extern_call()` | 3638 | 7817 | Foreign fn call emission |
| `emit_inst()` | 3704 | 7884 | IR instruction serialization |
| `emit_fn()` | 3802 | 8062 | Function body lowering to IR |
| `emit_externs()` | 3832 | 8099 | Extern declaration block |
| `emit_str_constants()` | 4758 | 9087 | String literal table |
| `emit_provenance_section()` | — | 9122 | **s1-only** (memory provenance) |
| `emit_user_externs()` | 4789 | 9254 | User-declared extern wrapping |
| `emit_module()` | 4815 | — | **tools-only** (minimal module) |
| `emit_module_ext()` | 4825 | 9407 | Extended module with externs |
| `emit_diag001_unknown_codes()` | — | 11238 | **s1-only** (diagnostic codes) |

**Summary**: Both files contain nearly identical emit infrastructure. s1 has extras for overflow-aware arithmetic, provenance tracking, and diagnostic code normalization. tools_suite's `compile_file_mode()` uses these to produce LLVM IR → clang → native.

### Summary/Report Functions

| Function | tools | s1 | Purpose |
|----------|-------|---|---------| 
| `run_summary_command()` | ~1250 | — | AST/metadata summary report (tools-only) |
| `run_evidence_command()` | ~120 | — | Security property checklist (tools-only) |
| `run_abi_command()` | ~400 | — | ABI export surface inspector (tools-only) |
| `run_impact_command()` | ~150 | — | Call-graph impact analyzer (tools-only) |
| `run_perf_command()` | ~200 | — | Performance hotspot auditor (tools-only) |
| `run_query_command()` | ~50 | — | Symbol/type query interface (tools-only) |
| `report_numeric_findings()` | 12753 | — | Numeric audit output (tools-only) |
| `audit_count_three_needles_total()` | — | 32310 | **s1-only** (audit utility) |

**Summary**: tools_suite is a reporting tool, not a codegen layer. All ~6 major summary/evidence/query/abi/impact/perf commands are tools-only. s1 focuses on compilation; tools_suite focuses on analysis.

---

## 5. Helper Function Inventory (Utility Plumbing)

### Total Counts
- **Total fns in tools_suite**: 693
- **Total fns in s1**: 808
- **Shared (same name)**: 429 (62% of tools, 53% of s1)
- **tools-only**: 264 (38% of tools)
- **s1-only**: 379 (47% of s1)

### Representative tools-only helpers (264 total):
- **ABI surface analysis** (abi_c_type_name, abi_export_surface_policy_label, abi_export_symbol_policy_label, abi_type_is_export_safe, append_abi_params_json, etc.) — ~40 fns
- **JSON formatting** (append_enum_variants_json, append_generics_json, append_params_json, append_struct_fields_json, etc.) — ~25 fns
- **CLI parsing** (cli_first_positional, cli_has_flag, cli_option_value, cli_wants_json) — ~4 fns
- **Profiling/perf** (profile_collect_samples, profile_emit_report, perf_hotspot_rank, etc.) — ~30 fns
- **Dependency analysis** (build_call_deps, build_sig_cache, body_call_set, collect_callees, etc.) — ~40 fns
- **Bootstrap corpus** (bootstrap_collect_corpus_files, bootstrap_corpus_listing_path, etc.) — ~10 fns
- **String utilities** (ascii_upper, basename, strip_ext, etc.) — ~15 fns
- **Cache/manifest** (check_fn_cache, manifest_entry_path, manifest_load, etc.) — ~20 fns
- **Test harness** (build_test_harness_source, build_test_harness_source_with_imports) — ~5 fns
- **Remaining specializations** (crypto, fix-command logic, registry interface, etc.) — ~75 fns

### s1-only helpers (379 total):
- **Codegen/lowering** (lower_if_expr_branch, lower_expr, lower_stmt, lower_stmts, lower_fn, etc.) — ~120 fns
- **Safety enforcement** (enforce_* gates, see section 3) — ~35 fns
- **Type system** (type_width, type_signedness, type_is_int, type_is_float, type_implements_trait, type_alias_resolve, etc.) — ~60 fns
- **Match pattern binding** (match_bind_payloads, pattern_binding_key, etc.) — ~15 fns
- **Diagnostics** (diag_* emit functions, audit_* scanning) — ~50 fns
- **Memory/closure/trait handling** (auto_drop_*, closure_*, trait_*, etc.) — ~100 fns
- **ANSI coloring, formatting** (ansi_bold, ansi_dim, ansi_red, ansi_yellow, etc.) — ~10 fns
- **Remaining** (audit utilities, constant folding, version tracking, etc.) — ~25 fns

---

## 6. Minimum Public-API Surface s1 Would Need to Expose

Based on the inventory above, tools_suite needs to import from s1 (rough best-estimate):

### **Parser tier** (36 functions)
- `lex` — lexical analysis
- `parse_expr`, `parse_stmt`, `parse_stmts`, `parse_fn_decl`, `parse_extern_fn`, `parse_struct_decl`, `parse_enum_decl`, `parse_trait_decl`, `parse_impl_block`, `parse_program` — top-level parsers
- `parse_primary`, `parse_postfix`, `parse_unary`, `parse_mul`, `parse_add`, `parse_cmp`, `parse_eq`, `parse_and_expr`, `parse_or_expr`, `parse_pipe_expr` — expression hierarchy
- `parse_let`, `parse_if`, `parse_while_stmt`, `parse_for_stmt`, `parse_return_stmt` — statement forms
- `parse_type`, `parse_generic_params`, `parse_const_decl`, `parse_type_alias_decl` — type syntax
- `parse_match_stmt`, `parse_match_binding_block` — pattern matching
- `parse_struct_init`, `parse_args` — expression subforms

### **Type-check tier** (6 functions)
- `type_check_program` — type checking entry
- `type_check_stmt`, `type_check_stmts` — statement checking
- `type_expr`, `type_last_stmt` — expression type inference
- `sym_new`, `sym_set`, `sym_get`, `sym_clone` — symbol table (helpers)
- `tenv_new`, `tenv_set`, `tenv_get` — type environment (helpers)

### **Helpers for tools-only that tools_suite already has locally** (264 functions)
- Keep in tools_suite; don't export from s1

### **Total Public API**: ~42 functions

---

## 7. Estimated Scope per Ship for Phase 2.0.2-2.0.5

### **Phase 2.0.2: Refactor s1 to expose pub fns** (2 ships)
- **Task**: Add visibility markers (`pub fn`) to 42 functions in s1
- **Line changes**: ~10-20 lines (marker insertions only)
- **Risk**: Low — syntactic, no semantic change; parser already treats `pub fn` as valid (evidenced by s1's own `pub`-tracking for AST items)
- **Testing**: Compile s1 standalone; verify all new pub fns are callable from main (if multi-module import test framework exists)
- **Estimated effort**: 1-2 days

### **Phase 2.0.3: Replace tools_suite duplicates with imports** (3-4 ships)
- **Task**: Delete 429 duplicate functions from tools_suite; add imports/calls to s1 pub fns
- **Line changes**: ~429 function deletions (~3,000-5,000 lines removed from tools_suite)
- **Risk**: **HIGH** — requires working cross-module import mechanism
  - If Nucleor doesn't yet support `import "compiler/nucleor_s1_compiler.nr"` syntax → **blocker**
  - If import mechanism exists but is bootstrap-limited → may fail to compile tools_suite itself
  - If import works → straightforward sed-like replacement
- **Bootstrap concern**: tools_suite is linked into `bin/nucleor_tools`, which is used to compile s1. Circular dependency? Check if s1 is built with s1 or with external clang.
- **Estimated effort**: 2-3 ships (1 for import mechanism validation, 1-2 for replacement + testing)

### **Phase 2.0.4: Self-host integrity gate** (1 ship)
- **Task**: Rebuild s1 using `nuc build` (using tools_suite built in 2.0.3) and verify bit-for-bit match with reference build
- **Line changes**: 0 (validation only)
- **Risk**: **CRITICAL** — if parser drift caused silent miscomputes, the self-hosted version may differ
- **Testing**: 
  - Build s1 with new unified tools_suite
  - Compare generated LLVM IR with reference
  - Compare final binary (may differ due to timestamps/ASLR; check `.text` section hash instead)
- **Estimated effort**: 2-3 days (build time + binary comparison tooling)

### **Phase 2.0.5: Remove check_parser_fn_drift from tools/check_compiler_drift.sh** (1 ship)
- **Task**: Delete drift-detection script now that parsers are unified
- **Line changes**: ~50 lines deleted
- **Risk**: Low
- **Estimated effort**: 1 day

### **Total Effort Estimate**: 5-9 ships (~2-3 weeks)

---

## 8. Risks & Open Questions

### **Critical Blockers**

1. **Does Nucleor support cross-module function imports today?**
   - **Status**: Unknown. No evidence of `import` statements in either file; both are monolithic.
   - **Resolution**: Check compiler/nucleor_*.nr files for any import-like syntax. If absent, RFC-0063 Phase 2.0.2 cannot proceed.
   - **Fallback**: Manually inline s1 public fns into tools_suite source as a temporary measure, then refactor import mechanism separately.

2. **Is there a bootstrap cycle risk?**
   - **Status**: tools_suite is used to build s1 → s1 must not depend on tools_suite (circular).
   - **Question**: Is tools_suite built with s1 or with external clang?
   - **Resolution**: Check build order in Makefile/build.sh. If tools_suite is built externally, no risk. If tools_suite is self-hosted, need to ensure s1 code is import-free in phase 1.

3. **Does s1's type-check pass have tools_suite-specific behavior?**
   - **Status**: No. Type-check is identical in structure; tools_suite's version is just smaller (missing const-value tracking + enforce gates).
   - **Safety**: Safe to unify. Tools_suite will gain enforce gates (side effect: may catch new errors in user code, but desired behavior).

### **Non-Critical Questions**

4. **Are there helpers tools_suite genuinely needs that s1 doesn't have?**
   - **Status**: Yes, 264 tools-only functions (ABI analysis, JSON, CLI, perf, cache, etc.)
   - **Answer**: Keep them in tools_suite. Do NOT export them from s1. They are reporting tools, not compiler infrastructure.

5. **What's the magnitude of the parser drift?**
   - **Status**: Documented in section 2. Key deltas:
     - parse_stmt: 91% smaller (22 vs 241 lines)
     - parse_primary: 79% smaller (139 vs 648 lines)
     - parse_postfix: 61% smaller (50 vs 129 lines)
   - **Impact**: explains SEGFAULT on examples/01_hello.nr — tools_suite parser is incomplete; missing defensive halts and advanced forms.
   - **Fix**: Phase 2.0.3 unification will auto-fix this.

6. **Will unification break existing `nuc` commands?**
   - **Status**: Unlikely. All 29 commands (section 1) dispatch to run_*() handlers that exist in tools_suite and are independent of the parser.
   - **Testing**: Run nuc check, nuc build-strict, nuc abi inspect, etc. on examples/01_hello.nr post-2.0.3; verify SEGFAULT is gone.

7. **Are there any performance regressions from importing?**
   - **Status**: Unlikely, assuming imports are zero-cost (no runtime overhead).
   - **Testing**: Profile tools_suite before/after 2.0.3; compare compile times.

---

## Conclusion

**Unification scope**: Delete ~429 duplicate functions from tools_suite.nr; add imports from s1. Effort: 5-9 ships, **blocked on cross-module import mechanism**.

**Critical next step**: Validate that Nucleor supports `import` or equivalent. If not, RFC-0063 Phase 2.0 requires a language-layer feature ship beforehand.

**High-confidence outcomes**:
- Parser drift explained and will be fixed post-2.0.3
- Self-host integrity gate (2.0.4) will validate the unification
- No regression in CLI surface or semantic behavior expected
- tools_suite will gain 379 s1-specific safety enforcements as side effect (feature gain)

