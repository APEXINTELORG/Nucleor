# RECON Pass-1 Audit — Diagnostic Correctness (Layer 3)

**Date:** 2026-05-08
**Scope:** Diagnostic-code emission paths in the compiler — message correctness, location accuracy, suggestion quality, multi-error mode, error recovery, code uniqueness.
**Binary:** `bin/nucleor.exe` v1.0 (path: `Nucleor_OSS_integrate_r05_with_row_v0842`)
**Methodology:** Source-level grep+read of `compiler/*.nr` for emit sites, mapped against `tests/err/*.nr` corpus, cross-checked by running `bin/nucleor.exe build` against representative tests with caches cleared. NO compiler edits, NO `verify.sh`. Scratch in `audit_scratch_diagnostics/`.
**Out of scope:** Whether the underlying detection is correct — only the diagnostic itself.

---

## Diagnostic Code Inventory

Emission paths in the compiler split across three mechanisms:

1. **`error[CODE]:` strings** — embedded in `panic(...)` or `print(...)` calls. No structured location. Fires before the diag pipeline. 39 distinct codes, ~85 emit sites.
2. **`diag_add_ex(diags, severity, checker, code, message, fn_name, line, col, related_id)`** — structured emit. 80 call sites in `nucleor_s1_compiler.nr`. ~50 distinct codes.
3. **`own_diag` / `own_diag_ex` / `type_diag`** wrappers around `diag_add_ex` — implicit "error" severity, "ownership" / "type" checker.

Severities used: `error`, `warning`, `info`.

### Inventory table — every emitted code → coverage

Tests counted against `tests/err/`. **"none"** = no negative test in `tests/err/` references the code by name.

| Code | Severity (emit sites) | Mechanism | Test in tests/err/ | Notes |
|---|---|---|---|---|
| ALIAS-G3-HASHMAP-REHASH | error | own_diag | `err_g3_hashmap_rehash_while_borrowed.nr` | |
| ALIAS-G3-VEC-OF-REFS | error | own_diag | `err_g3_vec_of_refs_push.nr` | |
| ASYNC-001 | warning | diag_add_ex | **none** | F-DIAG-006 |
| ATOMIC-001 | error | diag_add_ex (line=0,col=0) | `err_atomic_001_blocking.nr` | F-DIAG-005 (no source frame) |
| ATOMIC-002 | error | diag_add_ex (line=0,col=0) | `err_atomic_002_alloc.nr` | F-DIAG-005 |
| ATOMIC-003 | error | diag_add_ex (line=0,col=0) | `err_atomic_003_cell.nr` | F-DIAG-005 |
| ATOMIC-004 | error | diag_add_ex (line=0,col=0) | `err_atomic_004_cmpxchg_order.nr` | F-DIAG-005 |
| ATOMIC-005 | error | diag_add_ex (line=0,col=0) | `err_atomic_005_invalid_load_order.nr` | F-DIAG-005 |
| ATOMIC-006 | error | string panic | `err_atomic_006_in_closure.nr` | |
| BORROW-G2-LIFETIME | error | own_diag | `err_borrow_g2_lifetime_value_param.nr` | F-DIAG-002 (caret on fn header) |
| CONTRACT-004 | error | diag_add_ex | **none** | F-DIAG-006 |
| CONTRACT-005 | error | diag_add_ex | **none** | F-DIAG-006 |
| CONTRACT-006 | error | string panic | `err_contract_old_in_require.nr` | |
| CONTRACT-008 | error | string panic | `err_contract_old_vec_aliasing.nr` | |
| CONTRACT-009 | error | string panic | `err_dbc_mode_invalid.nr` | |
| CONTRACT-010 | error | string panic | `err_contract_result_in_void_fn.nr` | |
| CONTRACT-011 | error | string panic | `err_contract_undefined_ident.nr` | |
| DEPTH-001 | error | diag_add_ex | `err_depth_001_*.nr` | |
| DEPTH-002 | error | diag_add_ex | `err_depth_002_*.nr` | |
| DEPTH-003 | error | diag_add_ex | `err_depth_003_*.nr` | |
| DEPTH-004 | error | diag_add_ex | `err_depth_004_invalid_context.nr` | |
| DEPTH-005 | error | diag_add_ex | `err_depth_005_stack_budget.nr` | |
| DIAG-001 | warning | diag_add_ex | **none** | F-DIAG-006 |
| EFF-001 | **error AND warning** (split path) | diag_add_ex | `err_pure_violation.nr` etc. | F-DIAG-007 (severity collision) |
| EFF-002 | error | diag_add_ex | `err_effect_inference.nr` | |
| EFF-003 | error | diag_add_ex | `err_restricts_*.nr` | |
| EFFECT-G10-MISSING-ALLOW | error | diag_add_ex | `err_g10_effect_missing_allow.nr` | F-DIAG-002 |
| EFFECT-G10-UNDECLARED | error | diag_add_ex | `err_g10_effect_undeclared.nr` | F-DIAG-002 |
| EFFECT-G10-WRONG-ROW | error | diag_add_ex | `err_g10_effect_wrong_row.nr` | F-DIAG-002 |
| FFI-G5-NULL-DEREF | error | diag_add_ex | `err_g5_may_return_null_unguarded.nr` | F-DIAG-002 |
| FFI-G9-MISSING-ALLOW-DIRECT-FFI | error | diag_add_ex | `err_g9_direct_ffi_undeclared.nr` | F-DIAG-002 |
| INIT-G11-READ-BEFORE-INIT | error | own_diag | `err_init_g11_*.nr` | |
| ISR-001 | error | diag_add_ex (lc) | `err_isr_001_*.nr` | location OK |
| ISR-002 | error | diag_add_ex | `err_isr_002_with_deadline.nr` | |
| ISR-003 | error | diag_add_ex | `err_isr_003_unsupported_target.nr` | |
| ISR-007 | error | diag_add_ex (lc) | `err_isr_007_*.nr` | |
| ISR-008 | error | diag_add_ex (lc) | `err_isr_008_placement_on_struct.nr` | |
| LAW-001 | error | string print | **none in tests/err/** | F-DIAG-006 |
| LAW-003 | error | string print | `err_law_optimizer_without_check.nr` | |
| LAW-004 | error | string print | **none in tests/err/** | F-DIAG-006 |
| LAW-006 | error | string print | **none in tests/err/** | F-DIAG-006 |
| LAW-007 | error | string print | **none in tests/err/** | F-DIAG-006 |
| LAW-008 | error | string print | **none in tests/err/** | F-DIAG-006 |
| MATCH-008 | error | string panic | `err_match_pattern_wrong_type.nr` | F-DIAG-001 |
| MATCH-009 | error | string panic | `err_match_or_binding_mismatch.nr` | F-DIAG-001 |
| MATCH-012 | error | string panic | `err_match_012_struct_pattern_literal.nr` | F-DIAG-001 |
| MATCH-013 | error | string panic | `err_match_*` | F-DIAG-001 |
| MATCH-014 | error | string panic | `err_match_range_negative_*` | F-DIAG-001 |
| MATCH-015 | error | string panic | **none in tests/err/** (only `tests/fixtures/v0722_neg_lit_pattern_halt.nr`) | F-DIAG-006 |
| MOD-003 | error | string panic | `err_module_scope_union.nr` | F-DIAG-001 |
| MOD-005 | error | string panic | `err_import_cycle_*` | path OK, no line |
| NAM-001 | error | string panic | **none** | F-DIAG-006 |
| NR020 | error | string panic (byte_pos) | many | F-DIAG-001, F-DIAG-008 |
| NR022 | error | string panic | `err_paren_call_*` | F-DIAG-001 |
| NR023 | error | string panic | `err_chained_assignment.nr` | F-DIAG-001 |
| NR024 | error | string panic | `err_break_outside_loop.nr`, `err_continue_outside_loop.nr` | F-DIAG-001 |
| NR025 | error | string panic | `err_invalid_string_escape.nr` | F-DIAG-001 |
| NR035 | error | string panic | `err_nr035_enum_explicit_discriminant.nr` | F-DIAG-001 |
| NR036 | error | string panic | `err_nr036_self_recursive_struct.nr` | F-DIAG-001 |
| NUM-003 | warning | diag_add_ex (lc) | tests/err/* | location OK |
| NUM-009 | error | diag_add_ex (lc) | `err_num019_binop_negative_unsigned.nr` etc. | |
| NUM-021 | error | string panic | `err_int_lit_overflow.nr`, `err_num021_*` | F-DIAG-001 |
| OWN-001 | **warning** (only) | diag_add_ex (lc) | `err_use_after_move.nr`, `err_borrow_after_move.nr`, `err_box_use_after_move.nr` | **F-DIAG-003 (CRITICAL): warning severity → build succeeds RC=0 on use-after-move** |
| OWN-G4-USE-AFTER-DROP | error | own_diag | `err_own_g4_*.nr` | F-DIAG-002, F-DIAG-009 (truncated message) |
| OWN-G8-COND-MOVE | error | own_diag | `err_own_g8_cond_move_if_else.nr` | F-DIAG-002 |
| PERF-2 | warning | diag_add_ex | **none** | F-DIAG-006 |
| PERF-3 | warning | diag_add_ex | **none** | F-DIAG-006 |
| PKG-3 | error | string print | **none in tests/err/** | F-DIAG-006 |
| PKG-6 | error | string print | **none in tests/err/** | F-DIAG-006 |
| RACE-001 | error | diag_add_ex | `err_rfc0035_non_sendable_spawn.nr` etc. | F-DIAG-004 (line=0 → no caret) |
| RACE-002 | warning | diag_add_ex | `err_race_*` | |
| RACE-003 | error | diag_add_ex | `err_rfc0035_actor_field_escape.nr` | |
| RACE-005 | error | diag_add_ex (line=0) | `err_rfc0035_mut_ref_spawn.nr` | F-DIAG-004 |
| RACE-007 | warning | diag_add_ex | `err_race_unawaited_spawn.nr` | |
| RACE-008 | error | diag_add_ex (line=0) | `err_rfc0035_not_sendable_spawn.nr` | F-DIAG-004 |
| RT-001 | error | diag_add_ex (line=0) | `err_no_alloc_*` | F-DIAG-005 |
| RT-002 | error | diag_add_ex (line=0) | `err_no_panic_*` | F-DIAG-005 |
| RT-003 | error | diag_add_ex (line=0) | `err_no_dyn_violation.nr` | F-DIAG-005 |
| RT-004 | warning | diag_add_ex | `err_rt004_loop_keyword_counted.nr` | |
| RT-005 | warning | diag_add_ex | **none** | F-DIAG-006 |
| RT-006 | error | diag_add_ex (line=0) | `err_rt006_async_*` | F-DIAG-005 |
| RT-007 | warning | diag_add_ex | **none in err** | |
| RT-008 | warning | diag_add_ex | **none** | F-DIAG-006 |
| RT-009 | warning | diag_add_ex | tests/err/* | |
| SEND-G6-CLOSURE-CAPTURE | error | own_diag | `err_g6_closure_capture_spawn.nr` | F-DIAG-002 |
| SEND-G6-ENUM | error | own_diag | `err_g6_enum_with_hashmap_payload_spawn.nr` | F-DIAG-002 |
| SEND-G6-HASHMAP | error | own_diag | `err_g6_hashmap_spawn.nr` | F-DIAG-002 |
| SEND-G6-TUPLE | error | own_diag | `err_g6_tuple_with_hashmap_spawn.nr` | F-DIAG-002 |
| TNT-001 | warning | (suggestion only — no actual emit found) | **none** | F-DIAG-010 |
| TYP-002 | error | type_diag (fn_name as symbol) | `err_bool_arith.nr` etc. | F-DIAG-002 (always points at fn header) |
| TYP-005 | error | mixed (type_diag, panic, link-stage) | many | F-DIAG-008, F-DIAG-011 |
| TYP-007 | error | string panic | `err_chained_method_on_void.nr` | F-DIAG-001 |
| TYP-008 | error | type_diag (lc) | `err_if_branches_diff_types.nr` etc. | location OK (binding name) |
| TYP-011 | error | string panic | `err_str_index_in_arg.nr` | F-DIAG-001 |
| TYP-014 | error | string panic | `err_call_str_as_fn.nr`, `err_struct_as_fn.nr` | F-DIAG-001 |
| TYP-015 | error | string panic | `err_format_struct_no_display.nr` | F-DIAG-001 |
| TYP-039 | error | string panic | `err_typ_039_dup_field_in_struct_decl.nr` | F-DIAG-001 |
| TYP-040 | error | string panic | `err_typ_040_dup_enum_variant.nr` | F-DIAG-001 |
| TYP-041 | error | string panic | `err_typ_041_dup_struct_decl.nr` | F-DIAG-001 |
| UNSAFE-G7-MISSING-ALLOW | error | diag_add_ex | `err_g7_unsafe_undeclared.nr` | F-DIAG-002 |
| OWN-008 | error | own_diag | `err_immutable_assign.nr` | F-DIAG-002 (points at let, not assign) |
| OWN-004 | error | own_diag | `err_two_mut_borrows.nr` | F-DIAG-002 |

Plus **18 distinct codes emitted as `print("ERROR:` halt strings** (no `error[CODE]:` prefix, no diagnostic code at all — many `not yet supported` halts; e.g. `b"..."`, `c"..."`, `b'A'`, `r"..."`, `try { }`, `union`, `static`, `extern crate`, `macro_rules!`, `move ||`, `mut` on fn param, etc.). These are findable by grep `print(.*"ERROR:` (167 sites).

---

## Findings

### F-DIAG-001 — Parse-time diagnostics emit via `panic(...)` with no source location  [HIGH]

**Location:** `compiler/nucleor_s1_compiler.nr` lines 757, 828, 885, 1197, 1303, 1312, 1587, 1688, 1694, 1704, 1720, 2627, 4001, 4177, 27978, 28690, 31244, 31253 (18 sites). Codes affected: NR020, NR022, NR023, NR024, NR025, NR035, NR036, NUM-021, NAM-001, MATCH-012/013/014/015, MOD-003, TYP-007, TYP-011, TYP-014, TYP-015, TYP-039, TYP-040, TYP-041.

**Reproducer:**
```nr
fn main() -> i32 {
    let x = 1 +              // unfinished expression
    let b: bool = true;
    0
}
```

**Command:** `./bin/nucleor.exe build audit_scratch_diagnostics/parse_err.nr -o /tmp/pe`

**Observed:**
```
PANIC: error[NR020]: parse_primary cannot start an expression at token kind 11 (byte position 97). ...
```

No line number, no column, no source caret, no help frame. Adopters get a *byte offset* and have to manually convert to line:col. `error[NR020]` doesn't even render via the structured `diag_emit_text_with_source` formatter — it's a raw panic message.

**Expected:** Same Rust-style frame `--> fn:line:col` + caret produced for `diag_add_ex` codes.

**Remediation:**
1. `compiler/nucleor_s1_compiler.nr:1190-1197` — replace `panic(str_concat("error[NR020]: parse error at byte ", str_from_int(byte_pos), ...))` with `diag_add_ex(diags, "error", "parse", "NR020", msg, fn_name, byte_to_line(source, byte_pos), byte_to_col(source, byte_pos), "")` followed by `diag_emit_text_with_source(diags, source); panic("nucleor: parse error (see error above)");`.
2. Repeat for all 18 panic-emit sites listed above.
3. Add a regression test `tests/err/err_diag_parse_panic_has_location.nr` that asserts the error frame contains a `--> fn ... line N:M` line.

---

### F-DIAG-002 — `find_linecol_in_source(source, fn_name, fn_name)` always points at fn header  [MEDIUM]

**Location:** `compiler/nucleor_s1_compiler.nr:22288-22291` (`type_diag`), 22165-22176 (`own_diag`/`own_diag_ex`). Sites that pass the *function name* as the symbol (instead of the offending token's name) get caret on the `fn name` declaration row.

Examples confirmed by build:
- `TYP-002` (lines 23279, 23287): `type_diag(diags, source, fn_name, fn_name, "TYP-002", "boolean values cannot be used in arithmetic")` — caret lands on `fn main` row 1 col 4 even though the offending `b + 1` is at row 5.
- `OWN-008` (line 21162): `own_diag(own, fn_name, "OWN-008", ..., lname)` finds the FIRST occurrence of `lname` in the function body — the `let` declaration, not the `x = 20;` assignment site.
- `OWN-004` (line 22235): same pattern — caret on `fn main` for two-mut-borrow case.
- `EFF-001` (lines 11845, 11867, 11890, 19060): pure-fn violation — caret on `pure fn compute` not on the offending call site.
- `EFFECT-G10-*`, `FFI-G5-NULL-DEREF`, `FFI-G9-MISSING-ALLOW-DIRECT-FFI`, `UNSAFE-G7-MISSING-ALLOW`, `BORROW-G2-LIFETIME`, `SEND-G6-*`, `OWN-G4-USE-AFTER-DROP`, `OWN-G8-COND-MOVE` — same pattern verified.

**Reproducer:**
```nr
fn main() -> i32 {
    let b: bool = true;
    let y: i64 = b + 1;
    0
}
```

**Command:** `./bin/nucleor.exe build audit_scratch_diagnostics/bool_arith.nr -o /tmp/bool`

**Observed:**
```
error[TYP-002]: boolean values cannot be used in arithmetic
  --> fn main@line 1:4
  |
1 | fn main() -> i32 {
  |    ^
```

**Expected:** caret should be at the `b + 1` site (line 3 col 18).

**Remediation:**
1. Plumb `nid` (AST node id) through the type-checker into `type_diag`. Use `diag_add_at_or_scan(diags, source, pool, nid, fn_name, "error", "type", code, message, fn_name, "")` (already implemented at `nucleor_s1_compiler.nr:22293`) which prefers `node_get_span(pool, nid)` and falls back to symbol-scan.
2. Replace each `type_diag(..., fn_name, fn_name, ...)` call (15 sites) with the span-aware variant. `parse_primary` (line 2627 area) already attaches spans to var-ref nodes via `node_set_span`; ensure binop AST nodes carry the operator's span too.
3. For `own_diag`/`own_diag_ex` callers (`OWN-008`, `OWN-004`, `OWN-G4`, etc.), pass the AST nid of the offending expression and use `node_get_span` instead of `find_linecol_in_source(src, fn_name, vname)` (which is a textual first-match scan).
4. Add a new test `tests/err/err_typ002_caret_position.nr` that asserts the caret column matches the binop offset, not the fn declaration.

---

### F-DIAG-003 — OWN-001 (use-after-move) is emitted at "warning" severity, build succeeds RC=0  [CRITICAL]

**Location:** `compiler/nucleor_s1_compiler.nr:20545`:
```nr
let d_idx: i64 = diag_add_ex(diag_vec_move, "warning", "ownership", "OWN-001", ...);
```

The build halt logic at `nucleor_s1_compiler.nr:34507-34514` only halts when `diag_count_errors(diags) > 0`. OWN-001 is the lone safety-class diagnostic at "warning" severity (its sister codes OWN-G4, OWN-G8, BORROW-G2, INIT-G11, ALIAS-G3-*, SEND-G6-* are all "error" via `own_diag`).

**Reproducer:** `tests/err/err_use_after_move.nr` (already in corpus):
```nr
fn make_rect(width: i64, height: i64) -> Rect { ... }
fn main() -> i32 {
    let p: Rect = make_rect(10, 20);
    let r: Rect = consume_rect(p);
    let n: i64 = p.x;   // use of moved value
    0
}
```

**Command:** `rm -rf target/ && ./bin/nucleor.exe build tests/err/err_use_after_move.nr -o /tmp/uam`

**Observed:**
```
warning[OWN-001]: use of moved variable 'p'
  --> fn main@line 16:18
   ...
  compiled: target\uam.exe
RC=0
```

The build emits a warning, **produces a binary, and exits 0**. The use-after-move slips through. Adopters who do not pre-declare `#[deny(OWN-001)]` (most adopters) will ship code with reads of moved/freed memory.

This passes `tools/verify.sh` because the negative-test runner (line 1349) only greps `error\b|error\[|warning\b|warning\[` — the "warning" keyword satisfies the regex regardless of exit code.

Same defect verified for `err_borrow_after_move.nr` and `err_box_use_after_move.nr` (RC=0 with warning emitted).

**Expected:** OWN-001 should fail the build at "error" severity, consistent with the other ownership-family codes. RC=1 expected.

**Remediation:**
1. `compiler/nucleor_s1_compiler.nr:20545` — change the literal `"warning"` argument to `"error"` in the `diag_add_ex` call. The existing dedup, location, and child-note plumbing all stay.
2. Verify with `./bin/nucleor.exe build tests/err/err_use_after_move.nr` — should now produce RC=1.
3. Strengthen `tools/verify.sh` line 1346-1351: require BOTH the regex match AND `RC != 0` for negative tests. The current regex-only check is the load-bearing reason this slipped through — every other compiler defect emitting a warning would also pass.
4. Add a regression test `tests/err/err_use_after_move_exits_nonzero.nr` (or a fixture-runner assertion) that explicitly checks `RC=1`.

---

### F-DIAG-004 — `find_linecol_in_source(source, arg, arg)` returns line=0 col=0 for non-bare-ident args  [HIGH]

**Location:** `compiler/nucleor_s1_compiler.nr:15410-15411` (RACE-001/005/008 emit path).
```nr
let mut lc: Vec<i32> = find_linecol_in_source(source, arg, arg);
diag_add_ex(diags, "error", "race", code, msg, call_name, vec_get(lc, 0), vec_get(lc, 1), "");
```

`find_linecol_in_source` searches for a literal occurrence of `"fn " + fn_name`. When `arg` is `"&mut x"` (or any non-bare-ident), `"fn &mut x"` is never found → returns `(0, 0)`. The `diag_emit_text_with_source` formatter at line 19762 only renders the `--> fn:line:col` and source frame when `line > 0`, so the diagnostic prints with NO location at all.

**Reproducer:** `tests/err/err_rfc0035_mut_ref_spawn.nr` (already in corpus).

**Command:** `rm -rf target/ && ./bin/nucleor.exe build tests/err/err_rfc0035_mut_ref_spawn.nr -o /tmp/r35`

**Observed:**
```
error[RACE-005]: `&mut` argument `&mut x` crosses a thread boundary
RC=1
```

No `--> fn ... line:col`, no source frame, no caret. Same for RACE-001 (non-Sendable spawn) and RACE-008 (`#[not_sendable]` cross-thread).

**Expected:** Frame with `call_name@line:col` pointing at the spawn call site.

**Remediation:**
1. `compiler/nucleor_s1_compiler.nr:15410` — pass `call_name` (the spawn callee name, already in scope as `call_name`) as the *fn-name* argument to `find_linecol_in_source`, and pass either `arg` (with leading `&mut ` stripped) or a precomputed byte offset of the spawn call as the symbol. Better: at the spawn-call site, compute the offset of the open-paren via `sendable_find_matching_paren` (already used at line 15387) and call `byte_to_line(source, hit) / byte_to_col(source, hit)`.
2. Add a regression test `tests/err/err_race005_has_location.nr` that asserts `--> ` is present in the diagnostic.
3. Audit other diag_add_ex calls passing non-fn-name strings for the symbol lookup (4 sites in race + spawn paths) and apply the same fix.

---

### F-DIAG-005 — 23 `diag_add_ex` call sites pass `0, 0` literals for line/col  [HIGH]

**Location:** Codes affected (counts as ranges across the file):
- ATOMIC-001/002/003/004 (lines 16778, 16789, 16799, 16882, 16948)
- RT-001/002/003/006 (lines 16118, 16285, 16486, 16544, 18104)
- RT-004/005/007/008/009 (lines 19414, 17195, 18057, 19454, 16517, 16521)
- ASYNC-001 (line 18141)
- DIAG-001 (lines 11423, 11433, 11444, 11455)

These all hard-code `0, 0` as line/col → `diag_emit_text_with_source` skips both the `--> fn:line:col` line (gated `if line > 0`) and the source caret frame. Adopters get only the message + fn name, no source pointer.

**Reproducer:** `./bin/nucleor.exe build tests/err/err_atomic_001_blocking.nr -o /tmp/at` →
```
error[ATOMIC-001]: `sleep_ms` may block but `bad_atomic_blocking` is marked #[atomic]
```
No frame.

**Expected:** `--> fn bad_atomic_blocking@line N:M` plus caret at the offending `sleep_ms` call.

**Remediation:**
1. Each emit site already has the offending callee name in scope (e.g. `n` at line 16778). Wrap with `find_linecol_in_source(source, fn_name, n)` (or compute via existing AST nid) and pass the resulting line/col rather than `0, 0`.
2. Specifically:
   - `compiler/nucleor_s1_compiler.nr:16776-16778` (ATOMIC-001) — change to `let lc = find_linecol_in_source(body_source, fn_name, n); diag_add_ex(..., n, vec_get(lc,0), vec_get(lc,1), "");`. Repeat for ATOMIC-002/003 lines 16789, 16799.
   - `compiler/nucleor_s1_compiler.nr:16118, 16285, 16486, 16544, 18104` (RT-001/002/006) — same pattern.
3. Add a fixture asserting `ATOMIC-001` emits a `-->` line.

---

### F-DIAG-006 — 17 emitted codes have no negative test in `tests/err/`  [HIGH]

**Codes:** ASYNC-001, CONTRACT-004, CONTRACT-005, DIAG-001, LAW-001, LAW-004, LAW-006, LAW-007, LAW-008, MATCH-015, NAM-001, PERF-2, PERF-3, PKG-3, PKG-6, RT-005, RT-008.

(Also: TNT-001 — see F-DIAG-010.)

Of these, MATCH-015 has a positive fixture in `tests/fixtures/v0722_neg_lit_pattern_halt.nr` and several LAW codes have positive smoke tests in `tests/features/law_*` — but none of these run as part of the negative-test enforcement loop in `verify.sh`.

The negative-test runner (`tools/verify.sh:1346-1351`) drives only files in `tests/err/`. Codes without a `tests/err/` reproducer are never proven to actually fire. Several have suspicious internals — e.g. PKG-3 has 5 distinct emit sites with subtly different messages (`wildcard not yet supported`, `wildcard did not match`, `caret`, `tilde`, `compound range`) and zero coverage; regression risk on any future package-resolver edit is unbounded.

**Reproducer:** Take any code listed above. Grep `tests/err/` for it → no match.

**Remediation:**
1. Add one negative reproducer per uncovered code into `tests/err/`. Concrete examples:
   - `err_nam001_duplicate_param.nr` — `fn add(a: i64, a: i64) -> i64 { a + a }` (NAM-001 expected).
   - `err_diag001_unknown_allow_code.nr` — `#[allow(NOT-A-REAL-CODE)] fn main() -> i32 { 0 }` (DIAG-001).
   - `err_pkg3_wildcard_no_match.nr` — manifest with `foo = "9.*"` against an empty registry (or simulator stub).
   - `err_pkg6_git_dep.nr` — manifest with `foo = { git = "..." }`.
   - `err_law001_unknown_law.nr`, `err_law004_*`, etc. for each LAW code.
   - `err_async001_*`, `err_perf2_*`, `err_perf3_*`, `err_rt005_*`, `err_rt008_*`.
2. Each new file's `// EXPECT:` comment should include the literal code name and a substring of the emitted message.
3. Update `verify.sh` to fail if a new code is added in compiler sources without a sibling `tests/err/err_<code>_*.nr` (a static check against the inventory in this audit).

---

### F-DIAG-007 — EFF-001 emitted at both "error" and "warning" severity from different paths  [MEDIUM]

**Location:**
- `compiler/nucleor_s1_compiler.nr:11845, 11867, 11890, 18571, 18579, 19060, 19069` — emitted as `"error"`.
- `compiler/nucleor_tools_suite.nr:4471` — emitted as `"warning"` via `diag_add(... "warning", "effect", "EFF-001", ...)`.

Same code, same checker, same semantic class (pure fn calls effectful callee), but severity flips between the s1 path and the tools-suite path. Adopters cannot tell whether `EFF-001` is build-blocking or advisory. Test runner (regex-based) does not distinguish; both produce the same `verify.sh` PASS regardless of which path fired.

**Remediation:**
1. Pick one severity (recommended "error" for v1.0 — matches the s1 enforcement majority and the documented purity contract). Change `compiler/nucleor_tools_suite.nr:4471` to `"error"`.
2. Document the severity in `compiler/nucleor_s1_compiler.nr:11100` (the `is_error_code` table where EFF-001 is registered) so any future drift gets caught at code-review.
3. Add a `tests/err/err_eff001_severity_consistent.nr` regression that fails if the same EFF-001 condition produces a "warning" line.

---

### F-DIAG-008 — NR020 reused for 4 distinct semantic conditions; TYP-005 reused for 3+ conditions  [LOW]

**NR020 reuses (compiler/nucleor_s1_compiler.nr):**
- Line 1197: generic "expected token X, got Y" parser shortfall.
- Line 1303: "expected compile-time parameter name in RFC-0034 `[]` parameter list".
- Line 1312: "negative default literal is invalid for unsigned RFC-0034 compile-time parameter".
- Line 2627: "parse_primary cannot start an expression at token kind".

**TYP-005 reuses:**
- Line 23880: "wrong number of arguments for fn".
- Line 24300: "wrong number of arguments to closure".
- Various "undefined function" sites (incl. link-stage at clang).
- "Vec<T> has no method `.foo`" (line 28xxx area).
- "vec_*" related typos.

Diagnostic codes are intended to identify a single condition class (so `#[allow(CODE)]` and migration tools work). Reusing one code across heterogeneous conditions makes per-rule suppression overbroad: a user who `#[allow(NR020)]` to silence one specific sub-case loses parser feedback for unrelated parse errors.

**Remediation:**
1. Split NR020 into `NR020-EXPECTED-TOKEN`, `NR020-CT-PARAM-NAME`, `NR020-CT-PARAM-DEFAULT`, `NR020-PRIMARY-START`. Or, less invasive: keep NR020 as the family root and add sub-suffixes via the message header (e.g. `error[NR020.CT_PARAM_DEFAULT]:`) so external tooling can sub-classify.
2. Split TYP-005 into `TYP-005-WRONG-ARGC`, `TYP-005-UNDEFINED-FN`, `TYP-005-NO-METHOD` (the v1.0 docs are silent on the sub-conditions).
3. If splitting is post-v1.0: add a docs/diagnostics_index.md row per code documenting every distinct emit message + reproducer fixture so adopters at least know the matrix.

---

### F-DIAG-009 — OWN-G4-USE-AFTER-DROP emits a truncated message  [MEDIUM]

**Location:** Concatenation chain in `compiler/nucleor_s1_compiler.nr:20499-20506` produces messages ending mid-sentence at a literal backtick. Reproducible output:

```
error[OWN-G4-USE-AFTER-DROP]: use of 'v' after manual free (freed by 'vec_free'). The heap allocation is gone; reading the binding after `
```

The trailing backtick is followed by nothing — a `str_concat` chain terminates without the intended "vec_free` is undefined behavior" tail.

**Reproducer:** `./bin/nucleor.exe build tests/err/err_own_g4_double_vec_free.nr -o /tmp/o2`.

**Remediation:**
1. Audit the message-construction chain (search around line 20502-20506 in `compiler/nucleor_s1_compiler.nr`) for the missing tail string. Likely missing argument is a closing `str_concat` of `"...` is undefined behavior. Workaround: ..."`.
2. Add a regression test asserting the OWN-G4 message ends in a `.` (period), not a backtick.
3. Same backtick-mid-message risk likely exists in other long-chain `str_concat` emit messages — sweep all `panic(str_concat(...))` calls for trailing-paren depth mismatch.

---

### F-DIAG-010 — TNT-001 has a suggestion entry but no actual emission path  [HIGH]

**Location:** `compiler/nucleor_s1_compiler.nr:10709`:
```nr
if str_eq(code, "TNT-001") { sug_msg = "Sanitize the tainted data..."; sug_app = "HasPlaceholders"; };
```

The auto-suggestion table treats TNT-001 as a known code. But grep shows **no `diag_add_ex(...)` call ever passes "TNT-001" as the code argument** in `compiler/*.nr`. The code is a suggestion-only ghost.

`tests/err/err_taint_*.nr` exist (4 tests) — but they reference neither TNT-001 nor any taint-related emission code in their EXPECT lines. They likely emit some other code (TYP-005? EFF-001?). Tests might pass via the regex-only verify check.

**Reproducer:** `grep -rn '"TNT-001"' compiler/` → only the suggestion table at 10709.

**Remediation:**
1. Either: implement the taint checker emit path (search for taint flow in `nucleor_s1_compiler.nr` — likely at the per-arg call check around line 23000-25000 area) and wire `diag_add_ex(diags, "error", "taint", "TNT-001", ...)`.
2. Or: remove the dead suggestion entry at line 10709 and document taint as not-implemented in v1.0. Update `tests/err/err_taint_*.nr` `// EXPECT:` lines to reference whatever code actually fires (or move them out of `tests/err/` to a "future-feature" fixture dir).
3. Add a static check (build-time grep) that every entry in the suggestion table has at least one `diag_add_ex(... "CODE" ...)` call.

---

### F-DIAG-011 — TYP-005 misleadingly claims "type-checker emitted a TYP-005 warning earlier in this build"  [MEDIUM]

**Location:** TYP-005 link-stage post-mortem string. Reproducible:
```
error[TYP-005]: undefined function `undeclared_thing()`. Check spelling, or import the rod that defines it. (raised at clang link; type-checker emitted a TYP-005 warning earlier in this build.)
```

The **type-checker did NOT emit a prior warning** for `tests/err/err_undefined_var.nr` — the only TYP-005 in the build is the link-stage one. The parenthetical claim is false.

**Reproducer:** `./bin/nucleor.exe build tests/err/err_undefined_var.nr -o /tmp/uv` — single TYP-005, no prior warning in output.

**Remediation:**
1. Either: actually wire a type-checker pass that emits TYP-005 (warning) for unbound identifiers used as function callees, BEFORE codegen. Then the post-mortem claim becomes true.
2. Or: drop the parenthetical from the link-stage TYP-005 message. Search compiler source for the literal "type-checker emitted a TYP-005 warning earlier" and remove or correct it.
3. Add a regression that builds an undefined-callee program and asserts the count of TYP-005 lines matches the message's claim.

---

### F-DIAG-012 — Parser uses `panic` for parse errors, halts at first error (no recovery)  [MEDIUM]

**Location:** `compiler/nucleor_s1_compiler.nr:1197, 2627` (and 16 sister sites). Any parse failure short-circuits the entire compile.

**Reproducer:**
```nr
fn main() -> i32 {
    let x = 1 +              // parse error
    let b: bool = true;
    let c: i64 = b + 1;      // independent type error
    0
}
```

**Observed:** Only NR020 panics. The downstream TYP-002 (bool arith) is never seen.

**Expected (Rust-style):** parser uses ad-hoc recovery (skip-to-`;` or `}`) and continues; type-checker still runs; both errors reported.

**Remediation:**
1. Replace `panic("error[NR020]:...")` (line 1197) with: emit via `diag_add_ex`, attempt to recover by advancing tokens until next `;`, `{`, `}`, or `fn`/`let`/`return` keyword, then return a sentinel AST nid (e.g. a synthetic `Error` node).
2. Mark `parse_primary` and `expect` to short-return an error nid; consumers (`parse_let`, `parse_call`, etc.) propagate but don't crash.
3. At the end of parse, if `diag_count_errors > 0`, skip codegen but still run type/ownership/effect checks on the partial tree so adopters see all classes of issues in one pass.
4. Multi-error reporting for non-parse classes already works (verified: 2 type errors + 1 unrelated condition all reported in one build), so the goal is parity with the type-check pass.
5. Add a fixture `tests/err/err_multi_independent_errors.nr` containing 1 parse-recoverable error + 1 type error and assert both codes appear in the output.

---

### F-DIAG-013 — Two `diag_add_ex` definitions with identical bodies in different files  [LOW]

**Location:**
- `compiler/nucleor_s1_compiler.nr:10674`
- `compiler/nucleor_rfc0063_shared_wave2.nr:1131`

(Likewise: two `diag_add` definitions at `compiler/nucleor_s1_compiler.nr:10670` and `compiler/nucleor_rfc0063_shared_wave1.nr:1026`.)

The bodies are byte-identical (same dedup logic, same severity-pluck, same sug_msg auto-table). They exist because `nucleor_tools_suite.nr` imports the wave files and needs the function but does not import s1_compiler. This is dead-code duplication — any divergence (e.g. adding a new auto-suggestion) silently affects only one of the two paths.

**Remediation:**
1. Move `diag_add_ex` (and `diag_add`) into a shared header `.nr` that both `s1_compiler.nr` and `nucleor_rfc0063_shared_wave2.nr` import. Recommended: extract to `compiler/nucleor_diag.nr` and import from both call-sites.
2. If the import cycle prevents that today (s1 cannot import rfc0063 without circular ref), at minimum add a sync-check pre-pass to `tools/check_compiler_drift.sh` that fails if the two `diag_add_ex` bodies diverge.
3. Note for future hardening: the auto-suggestion table at lines 10708-10710 / 1165-1167 is duplicated. Adding a new code's suggestion to one file and not the other will create a per-path UX gap.

---

### F-DIAG-014 — Negative-test runner accepts diagnostic-presence regex without checking exit code  [HIGH]

**Location:** `tools/verify.sh:1349-1351`:
```sh
echo "$out" | grep -qiE 'error\b|error\[|warning\b|warning\[' \
    && finish PASS "$dt" "" \
    || finish FAIL "$dt" "no_error_or_warning_emitted"
```

Tests pass if the *string* "error" or "warning" (case-insensitive) appears anywhere in stdout/stderr — regardless of exit code, regardless of whether the named code is the expected one, regardless of whether the build actually succeeded.

This is the load-bearing reason F-DIAG-003 (OWN-001 warning shipping a binary) slipped through. It also masks F-DIAG-010 (TNT-001 missing emit) — `err_taint_*.nr` tests probably pass on some other code's output.

**Remediation:**
1. `tools/verify.sh:1346` — capture exit code: `out=$("$BIN" build ... 2>&1); rc=$?`.
2. Change the gate to `if echo "$out" | grep -qE 'error\[|warning\[' && [ "$rc" -ne 0 ]; then PASS; else FAIL; fi`.
3. Stronger: parse the test's `// EXPECT: error[CODE] ...` line and require the literal CODE to appear in the build output. If a test EXPECTs `error[OWN-001]` but the build emits `warning[OWN-001]` (or fires an unrelated TYP-008), the test should FAIL.
4. After tightening, expect a wave of pre-existing failures (every test currently passing on stale severity) — fix or quarantine them.

---

### F-DIAG-015 — Suggestions are auto-attached for only 3 codes  [LOW]

**Location:** `compiler/nucleor_s1_compiler.nr:10708-10710`:
```nr
if str_eq(code, "OWN-001") { sug_msg = "Consider cloning..."; sug_app = "MaybeIncorrect"; };
if str_eq(code, "TNT-001") { sug_msg = "Sanitize..."; sug_app = "HasPlaceholders"; };
if str_eq(code, "EFF-001") { sug_msg = "Declare the required effect..."; sug_app = "MaybeIncorrect"; };
```

Of ~90 emitted codes, only 3 have auto-suggestions. The rest emit no `help: ...` line. `MATCH-014` carries a verbose workaround inline in the message; `OWN-G8` likewise — the message-vs-suggestion split is inconsistent.

Suggestion compile-correctness was checked for the OWN-001 case ("clone the value...") — the suggestion is generic, doesn't mention the actual binding name, and "clone" is not implemented for arbitrary `struct` types in v1.0 (only Vec / HashMap / primitives). For a `struct Rect` use-after-move, "clone" is non-actionable.

**Remediation:**
1. Audit the 3 auto-suggestions for compile-validity:
   - OWN-001 "clone" — verify `.clone()` works for the binding's declared type. Today, structs without `#[derive(Clone)]` cannot be cloned; the suggestion compiles only ~20% of the time.
   - EFF-001 "declare the required effect" — actionable but doesn't include the actual effect name; templating would help.
2. Add suggestions for high-traffic codes: TYP-008 (could suggest the expected type), NUM-003 (could suggest the wider type or explicit `as`), MATCH-008 (could list the missing variant).
3. Consider adopting Rust's `Applicability` enum semantics — emit `sug_app = "MachineApplicable"` only when the suggestion is byte-for-byte compilable.

---

### F-DIAG-016 — Unrecognized identifier as variable read produces no diagnostic from type-checker  [MEDIUM]

**Location:** Type-checker has no "undefined variable" emit. Reproducer (`tests/err/err_undefined_var.nr` already exists):
```nr
fn main() -> i64 {
    let x: i64 = undeclared_thing + 1;
    ...
}
```

**Observed:** Type-checker silently accepts `undeclared_thing` as a function reference; codegen lowers it as an indirect call; clang link fails with `unresolved external symbol undeclared_thing`. Compiler reports TYP-005 only at the link stage (post-IR-emission), not during ownership/type/effect checks.

**Expected:** Type-checker emits TYP-005 (or new TYP-024 / TYP-NOT-IN-SCOPE) at the variable read site, with caret at `undeclared_thing`.

**Remediation:**
1. In `check_expr` for var-ref kind (around line 20520+), check whether `vname` is bound in the scope/sym table. If unbound and not a top-level fn, emit `TYP-005-UNBOUND` (or a new TYP-NN-UNDEFINED-IDENT) at the var-ref's span.
2. Stop deferring to the linker. The link-stage diagnostic at TYP-005 should remain as a backstop only when type-check is suppressed.
3. Adjust `tests/err/err_undefined_var.nr` `// EXPECT:` comment to reference the new pre-link diagnostic.

---

### F-DIAG-017 — `print("ERROR: ...not yet supported...")` halts emit no diagnostic code  [LOW]

**Location:** ~167 sites in `compiler/nucleor_s1_compiler.nr` matching `print("ERROR:`. Most are "not yet supported" walls of text for unimplemented Rust syntax (byte literals, raw strings, `union`, `static`, `try {}`, `macro_rules!`, `move ||` closures, etc.).

These halts:
- Print to stdout instead of stderr (depending on platform, may interleave with build progress).
- Carry no `error[CODE]:` prefix and no diagnostic code → adopters can't `#[allow(...)]` them.
- Have no source location or caret.
- Exit via a follow-up `panic("nucleor: <feature> not yet supported")` line.

The verify-test corpus (e.g. `tests/err/err_byte_string_literal.nr`, `err_c_string_literal.nr`, `err_macro_rules.nr` if present) just greps for "ERROR:" or "not yet supported" — they pass regardless of which halt fired.

**Remediation:**
1. Adopt a single not-implemented diagnostic family, e.g. `NYI-NNN` for "not yet implemented", with a stable mapping (NYI-001 = byte string literal, NYI-002 = c string, NYI-003 = raw string, etc.).
2. Convert each `print("ERROR: ..."); panic(...);` pair into a `diag_add_ex(diags, "error", "nyi", "NYI-NNN", ...)` plus structured halt.
3. Adopters can then `#[allow(NYI-005)]` to silence individual not-yet-supported syntax forms during a port (if they have a workaround) without disabling all NYI checks.
4. Add a `docs/diagnostics_NYI.md` mapping every NYI-NNN to the rust-syntax-form it covers and the canonical Nucleor workaround.

---

## Severity summary

| Severity | Count | Codes |
|---|---|---|
| Critical | 1 | F-DIAG-003 (OWN-001 warning → use-after-move ships a binary RC=0) |
| High | 6 | F-DIAG-001, F-DIAG-004, F-DIAG-005, F-DIAG-006, F-DIAG-010, F-DIAG-014 |
| Medium | 6 | F-DIAG-002, F-DIAG-007, F-DIAG-009, F-DIAG-011, F-DIAG-012, F-DIAG-016 |
| Low | 4 | F-DIAG-008, F-DIAG-013, F-DIAG-015, F-DIAG-017 |

**Headline:** OWN-001 emits at warning severity (single line edit at `compiler/nucleor_s1_compiler.nr:20545`). Combined with `verify.sh`'s regex-only negative-test gate (F-DIAG-014), use-after-move slips through every layer of v1.0 enforcement and produces a binary that reads moved/freed memory. This is the sole CRITICAL finding and the single most leveraged fix.

The HIGH cluster (F-DIAG-001/004/005) all stem from the same root cause: location is computed via textual scan with `find_linecol_in_source(source, fn_name, ...)` instead of via AST node spans (`node_get_span(pool, nid)`). The infrastructure for span-aware diagnostics exists (`diag_add_at_or_scan` at line 22293) but is used inconsistently. A systematic conversion would close most of these in one pass.

The HIGH coverage gap (F-DIAG-006) is structural: 17 emitted codes have no negative test; the test runner accepts any "error|warning" regex match (F-DIAG-014). Tightening the runner without first adding the missing tests will produce a flood of failures.

No findings would block a v1.0 launch in isolation, but F-DIAG-003 is a known-defective safety property the project documents as a launch criterion (see `feedback_nucleor_self_host_validation.md` — auto-drop double-free was the v0.8.119 root cause, sister to use-after-move). Recommend gating launch on F-DIAG-003 + F-DIAG-014 only; the rest are polish/hardening.
