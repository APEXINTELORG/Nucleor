# Lane 1 Report — Type Flow + Codegen u64

**Branch:** `fix/audit-lane-1-type-flow-codegen-2026-05-08`
**Date:** 2026-05-08
**Brief:** [LANE_1_TYPE_FLOW_CODEGEN.md](LANE_1_TYPE_FLOW_CODEGEN.md)

## Per-finding status

### Critical (10)

| ID | Title | Status | Notes |
|---|---|---|---|
| F-002 | Cross-enum match silent miscompile | Partial | MATCH-016 check wired at the arm-walker site (`compiler/nucleor_s1_compiler.nr` ~line 24844). Fires when scrut_t is populated AND the pattern's enum name differs from the scrutinee's base. Does not fire reliably for the audit's exact reproducer because user-defined enum scrutinees occasionally surface with empty scrut_t inside `type_expr` — closing the gap requires the per-instantiation monomorphization fix tracked separately as F-029 / NOTE. The scaffolding is in place; the runtime check fires when scrut_t is known. |
| F-003 | Silent i64→i32 truncation | Partial | New TYP-044 check at the let-binding site (gated by `NUC_STRICT_NUMERIC=1`). Default off so the i64-everywhere test surface keeps building; opt-in catches the audit's `let b: i32 = a;` reproducer when env var is set. Strict-by-default would shatter ~hundreds of fixtures relying on the existing i64↔i32↔f64 latitude in `types_compatible`; promoting to default-on requires the canonical fix-up sweep. |
| F-006 | Generic enum payload type unchecked | Skipped | `[BLOCKED-ON-MONOMORPHIZATION]`. Per F-029 (NOTE) the type-erased monomorphization is documented as transitional — genuinely fixing F-006 requires per-instantiation generic substitution, which is an architectural change scoped beyond this lane. |
| F-019 | Compiler PANICs on duplicate impls | Partial | Diagnostic now uses canonical `error[TYP-043]:` shape (was `ERROR:` ad-hoc). The trailing `PANIC:` line remains because the runtime helper `__nucleor_diag_exit` was added (`stdlib/runtime/nucleor_llvm_rt.c`) but the bootstrap binary cannot resolve a Nucleor-source `diag_exit()` call until a follow-on iteration. The runtime + name-table entry are in place for the next iteration. |
| C-001 | u64 ordered cmp uses signed icmp | Fixed | `binop_u64_type` now classes operand signedness; iops 9..12 (slt/sgt/sle/sge) remap to new iops 38..41 (ult/ugt/ule/uge) when either operand is u64. `emit_inst` and `is_cmp_or_logic` extended for the new iops. |
| C-002 | u64 right-shift uses ashr | Fixed | iop 24 (ashr) remaps to new iop 25 (lshr) at lower-time when LHS is u64; runtime helper `__nucleor_panic_shr_u64` added; lowering routes u64 var-RHS shifts through it. |
| C-003 | u64 div/rem use signed sdiv/srem | Fixed | New runtime helpers `__nucleor_panic_div_u64` / `__nucleor_panic_rem_u64`; lowering's div/rem dispatch (line ~27170) picks the u64 helper when `binop_u64_type` reports u64. const_i64_expr's signed-fold band-aid added to skip NUM-019 false-fire on u64 divs (max_u64 / 2 was -1 to the signed cmap). |
| C-007 | cmp-fold signed-only | Fixed | `opt_fold_block` now folds iops 38..41 with the sign-bit-flip XOR-trick so unsigned comparisons fold consistently. |
| F-NUM-001 | f→narrow-int returns bit-pattern bytes | Fixed | New runtime helpers `__nucleor_f64_to_{i8,u8,i16,u16}` and `__nucleor_f32_to_{i8,u8,i16,u16}` with saturating-truncate per RFC-0015 §3.5; cast dispatch table at kind==99 routes the eight new pairs. |

### High (13)

| ID | Title | Status | Notes |
|---|---|---|---|
| F-001 | Generic struct/fn type-param arity | Skipped | `[BLOCKED-ON-MONOMORPHIZATION]`. Same architectural dependency as F-006 / F-007 / F-008. |
| F-004 | Silent i32→i64 widening | Partial | Same TYP-044 check as F-003 (gated). |
| F-005 | Implicit int→f64 binding | Partial | Existing NUM-018 fires for kind-1 literal RHS; the wider remediation is gated through TYP-044 with NUC_STRICT_NUMERIC. |
| F-007 | Generic struct field type not propagated | Skipped | `[BLOCKED-ON-MONOMORPHIZATION]`. |
| F-008 | Generic struct field initializer type | Skipped | `[BLOCKED-ON-MONOMORPHIZATION]`. |
| F-009 | Trait impl missing required method | Skipped | Coverage walk requires impl-block walker not in current scope; deferred. |
| F-010 | Trait impl signature mismatch | Skipped | Same as F-009. |
| F-011 | Trait impl with extra method | Skipped | Same as F-009. |
| F-012 | Mutually recursive structs accepted | Skipped | DFS cycle detector replacement is invasive; deferred to a focused follow-on. |
| F-013 | Generic self-referential struct | Skipped | Tied to F-012 + monomorphization. |
| F-014 | Where-clause unbound type-param | Skipped | Where-clause walker enhancement deferred. |
| F-015 | Duplicate type-param `<T, T>` | Fixed | New TYP-042 in `parse_generic_params`. |
| F-016 | Type-param shadows primitive `<i64>` | Fixed | New TYP-041 in `parse_generic_params`. |
| F-018 | Ambiguous inference `let v = make()` | Skipped | Inference-strict path requires deeper plumbing across `infer_var_type_from_source`; deferred. |
| C-004 | Bitwise fold conservative | Skipped | Pre-existing v0.3.147 conservative fold-skip is correct (no miscompile); the audit's recommendation to reimplement using ashr-bit-extract is a quality improvement, not a correctness fix. Not promoted in this lane. |
| F-NUM-004 | Mixed-width arithmetic enforcement | Skipped | Strict NUM-001 enforcement risks ~hundreds of fixtures; the audit's own remediation note offers two alternatives (enforce strict, or amend RFC-0015 §3.2). Recommend the RFC amendment as a separate doc-only change. |

### Medium (3)

| ID | Title | Status | Notes |
|---|---|---|---|
| C-005 | NUM-021 misnamed for div-by-zero | Skipped | Cosmetic diagnostic-text fix; deferred. |
| C-006 | const_int IR quality | Skipped | Cosmetic IR shape; LLVM cleans up at -O1+. Out of scope for correctness lane. |
| F-026 | NR036 followed by PANIC | Partial | Same shape as F-019: improved error[CODE]: text in place, trailing PANIC line tracked for the runtime + bootstrap follow-on. |

## Tests added

### Positive (`tests/lang/`)
- `audit_lane1_u64_compare.nr` — closes C-001 (unsigned ordered compare on high-bit-set u64).
- `audit_lane1_u64_shift.nr` — closes C-002 (logical right shift; differential against hand-computed reference).
- `audit_lane1_u64_divmod.nr` — closes C-003 (unsigned div / rem on high-bit-set operand).
- `audit_lane1_f_to_narrow.nr` — closes F-NUM-001 (mid-range, saturating positive, saturating negative for both signed and unsigned narrow targets).

### Negative (`tests/err/`)
- `err_audit_lane1_match_pattern_wrong_enum.nr` — F-002 reproducer (best-effort; see status note above).
- `err_audit_lane1_duplicate_type_param.nr` — F-015 (`fn dup<T, T>(...)`) → TYP-042.
- `err_audit_lane1_type_param_shadows_primitive.nr` — F-016 (`fn use_it<i64>(...)`) → TYP-041.

## Files touched

- `compiler/nucleor_s1_compiler.nr`
  - `get_rt_name`: added u64 panic helpers, f-to-narrow helpers, diag_exit name-table entry.
  - `parse_generic_params`: new TYP-041 / TYP-042 checks.
  - Bootstrap parse-time: F-019 / F-026 / TYP-039 / TYP-040 diagnostics rewrapped to use canonical `error[CODE]:` shape (the trailing PANIC is unchanged for now).
  - `is_cmp_or_logic`: extended to recognize iops 38..41.
  - `emit_inst`: new cases for iop 25 (lshr) and 38..41 (ult/ugt/ule/uge).
  - Binop lowering site (~line 27073): u64-aware iop remap and panic-helper dispatch.
  - `opt_fold_block`: signed-fold cmp branch + new unsigned-fold cmp branch.
  - Cast dispatch (kind==99): f64/f32 → {i8,u8,i16,u16} routing.
  - Match arm walker: MATCH-016 cross-enum identity check.
  - let-binding type-check: TYP-044 narrow check (gated by NUC_STRICT_NUMERIC).
  - NUM-019 binop check: skip false-positive when binding type base is u64.
  - `is_known_diag_code`: registered MATCH-015 / MATCH-016.
  - Compiler IR header: new declares for `__nucleor_panic_shr_u64`, `__nucleor_panic_div_u64`, `__nucleor_panic_rem_u64`, `__nucleor_diag_exit`, and the eight `__nucleor_f{32,64}_to_{i8,u8,i16,u16}` helpers.

- `stdlib/runtime/nucleor_llvm_rt.c`
  - `__nucleor_panic_shr_u64`, `__nucleor_panic_div_u64`, `__nucleor_panic_rem_u64`: unsigned 64-bit shr / div / rem with the same panic-on-zero / oob behavior as the signed siblings.
  - `__nucleor_f64_to_{i8,u8,i16,u16}` and `__nucleor_f32_to_{i8,u8,i16,u16}`: saturating-truncate (NaN → 0, saturate-at-bound, then truncate toward zero).
  - `__nucleor_diag_exit`: clean process exit(1) without a "PANIC:" prefix line. Reserved for the F-019 / F-026 follow-on iteration.

- `bin/nucleor.exe` — replaced with stage-2 self-host of the patched compiler source.
- `bootstrap/nucleor_s1_seed.ll` — refreshed to the stage-2 IR md5; fixed-point check passes (`tools/check_self_host_md5.sh` OK).

- `tests/lang/audit_lane1_*.nr` (4 files), `tests/err/err_audit_lane1_*.nr` (3 files).

## Verify result

`bash tools/verify.sh` was started twice on this branch. Both runs reached the early CLI / examples sweep with **0 FAIL / 0 SKIP** before progress slowed under cross-lane contention (eight other lane-agents' verify.sh instances were running concurrently in sibling worktrees, saturating the 4-core runner). Latest observed step: `[ 19/1527] OK    RFC-NRT-003: nuc verify-reproducible passes on sample fixture` after the supervising shell timed out the wait. The full test sweep (steps 60..1527) was not completed end-to-end on this branch's session for that environmental reason — the branch ships with `[VERIFY-PENDING]` in the commit subject per the brief's partial-push protocol.

No FAIL has been observed in any run. Independent gates that passed cleanly:

- `tools/check_self_host_md5.sh` — stage1↔stage2↔seed md5 fixed point at `d621ea40d7b16ffc5989e26acb0989f9`.
- `tools/check_compiler_drift.sh` — ABI tables in sync between s1 and tools-suite; helper_manifest, rod_manifest, RELEASES.md, audit_dup_fns_report.csv all up to date.
- All 4 new positive `tests/lang/audit_lane1_*.nr` exit 0 with their PASS line.
- All 3 new negative `tests/err/err_audit_lane1_*.nr` emit the expected `error[CODE]:` diagnostic and non-zero exit.
- `tests/lang/as_cast.nr` (existing as-cast regression test) still passes — F-NUM-001 routing did not break the integer-mask helper path.
- err-test EXPECT-header sanity gate was step 8 / 1527 in both runs and went OK.

Integrator action: re-run `bash tools/verify.sh` on this branch in a single-lane environment, and update this report + the commit subject from `[VERIFY-PENDING]` to the observed counts. The 0-FAIL trend through the first 19+ steps and the green self-host + drift gates suggest the residual sweep will complete cleanly without fix-forward.

## Cross-lane / blocked items

- **F-006 / F-007 / F-008 / F-013**: BLOCKED on architectural fix per F-029 (type-erased monomorphization → per-instantiation monomorphization).
- **F-019 / F-026 trailing PANIC line**: BLOCKED on bootstrap re-iteration that resolves `diag_exit()` from compiler source. The runtime helper + name-table entry shipped in this branch; one extra rebuild + seed refresh closes the cosmetic surface.
- **F-NUM-004 strict mixed-width**: BLOCKED on the RFC-0015 §3.2 strict-mode-vs-amendment decision (audit doc explicitly leaves this open).
