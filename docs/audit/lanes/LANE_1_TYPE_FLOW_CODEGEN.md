# Lane 1 — Type Flow + Codegen u64 (the i64-everywhere thread)

**Branch:** `fix/audit-lane-1-type-flow-codegen-2026-05-08`
**Theme:** Make type info flow correctly from frontend → monomorphization → codegen → numeric ops. Closes the systemic root cause that ties Layer 2 generic erasure to Layer 6 u64 silent miscompiles to Layer 8 float-cast bugs.

## In-scope findings

### Critical (10)
- **Layer 2 / F-002** — Cross-enum match silent miscompile (`A::Red` matches `B::On`)
- **Layer 2 / F-003** — Silent i64→i32 truncation (`1234567890123` prints as `1912276171`)
- **Layer 2 / F-006** — Generic enum payload type not checked (`Holder<i64>::Some("hello")` accepted)
- **Layer 2 / F-019** — Compiler PANICs on duplicate impls instead of clean diagnostic
- **Layer 6 / C-001** — `u64 < u64` emits `icmp slt i64` (signed compare on unsigned)
- **Layer 6 / C-002** — `u64 >> n` emits `ashr` instead of `lshr` (sign-extending right shift on unsigned)
- **Layer 6 / C-003** — `u64 / u64` and `u64 % u64` route to signed panic helpers; no `_u64` runtime helpers exist
- **Layer 8 / F-NUM-001** — `f64/f32 as {i8,u8,i16,u16}` returns LOW BYTES of bit pattern instead of saturating-rounding

### High
- **Layer 2** all 12 High findings on generic erasure: arity not checked, implicit widening, struct field types not propagated, impl method coverage not checked, mutually-recursive structs accepted, where-clause undefined params, ambiguous inference accepted, etc.
- **Layer 6 / C-004** — bitwise fold conservatively skips negative operands
- **Layer 8 / F-NUM-004** — RFC-0015 §3.2 mixed-width arithmetic enforcement (NUM-001) absent

### Medium
- **Layer 6 / C-005** — `100 / z` (where z=0 propagates) emits NUM-021 "overflow" instead of NUM-009 "divide by zero"
- **Layer 6 / C-006** — `const_int` materializes as `add i64 K, 0` (cosmetic IR bloat)
- **Layer 6 / C-007** — cmp fold signed-only (rolled into C-001 fix)

## Source-of-truth findings docs
- `docs/audit/findings/audit_recon_pass1_typesystem_2026-05-08.md`
- `docs/audit/findings/audit_recon_pass1_codegen_2026-05-08.md`
- `docs/audit/findings/audit_recon_pass1_numeric_2026-05-08.md` (only F-NUM-001 + F-NUM-004)

## Strategy

**Root cause is type information not propagating through monomorphization.** Don't band-aid the codegen u64 sites — fix the type-flow so codegen receives concrete types and emits the right LLVM ops.

Sketch (lane agent confirms specifics from compiler/nucleor_s1_compiler.nr):
1. **Monomorphization carries concrete types.** Generic struct/enum field types must be substituted with the concrete instantiation; payload type-checked at call site.
2. **Codegen reads concrete int signedness.** `emit_cmp` / `emit_inst` / `tok_to_ir` switch on signed-vs-unsigned and emit `icmp slt` vs `icmp ult`, `ashr` vs `lshr`. Add `__nucleor_panic_div_u64` / `_rem_u64` runtime helpers.
3. **Float→narrow-int paths.** Add `__nucleor_f64_to_{i8,u8,i16,u16}` helpers with saturating-round semantics per RFC-0015 §3.5. Wire cast dispatch table.
4. **Cross-enum match.** Pattern match must check the scrutinee's enum type matches the constructor's enum type.
5. **Diagnostic clean-up.** Replace any PANIC paths with proper diag emits (consistent with Lane 3's general anti-pattern fix; coordinate via diff if needed).

## Test mandate

For every Critical fixed:
- Add `tests/lang/<positive>.nr` exercising the now-correct path
- Add `tests/err/<negative>.nr` exercising the diagnostic when the wrong shape is provided

The negative tests MUST exit non-zero (per Lane 3's exit-code-aware runner — coordinate if Lane 3 hasn't landed yet by adding `# expect-rc: 1` comment that future runner will honor).

For Lane 6 codegen fixes: add a **differential test** — equivalent program in C compiled with clang, same numeric output bit-exact.

## Verify policy

Run `bash tools/verify.sh` ONCE at end of batch. Target: PASS=N+M / SKIP=3 / FAIL=0 where M = new tests added.

If verify FAILS due to fixed-point drift after the codegen changes, regenerate `bootstrap/nucleor_s1_seed.ll` and `bin/nucleor.exe` per the standard procedure (`tools/regen_seed.sh`, `tools/regen_bin.sh` — confirm names from existing tools).

## Hard constraints

- All fixes on the lane's own branch; do NOT push to `main` or other lanes' branches.
- Do NOT modify findings docs.
- Do NOT touch files outside the typesystem/codegen/numeric scope unless cross-lane coordination is required (in which case, document in branch commit message).
- Final push only if FAIL=0 OR with explicit verify report attached and `[PARTIAL]` flag in branch summary.

## Output

- Branch pushed to `origin` (archive) at `fix/audit-lane-1-type-flow-codegen-2026-05-08`
- Final report committed to branch as `docs/audit/lanes/LANE_1_REPORT.md`: per-finding status (Fixed/Partial/Skip-with-reason), verify result, files touched, tests added.
