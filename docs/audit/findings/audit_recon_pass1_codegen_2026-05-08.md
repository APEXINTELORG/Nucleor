# RECON AUDIT — Layer 6: Codegen (LLVM IR + binary correctness)

Date: 2026-05-08
Auditor: Claude (Opus 4.7, 1M ctx) — codegen-focused recon pass 1
Repo: `C:\Users\JoeWe\Desktop\Nucleor_OSS_integrate_r05_with_row_v0842`
Compiler: `bin/nucleor.exe` (Nucleor 1.0.0)
Bootstrap seed: `bootstrap/nucleor_s1_seed.ll` (md5 in NUCLEOR_BOOTSTRAP_CONTRACT)
Source under audit: `compiler/nucleor_s1_compiler.nr` (40,983 LOC)

Scratch artifacts: `audit_scratch_codegen/` (22 test programs, t01..t23)

---

## Executive summary

Codegen for the **default i64-plus-typed-narrower** numeric path is broadly correct. The fixed-point self-host invariant, byte-identical reproducible builds (`/Brepro`, `--build-id=none`), strict overflow intrinsics for typed narrower widths (`sadd.with.overflow.i32`, `uadd.with.overflow.i32`, etc.), div/rem panic helpers, and shift OOB traps all behave as documented and as the source-tree comments claim.

**However, unsigned 64-bit (`u64` and `usize` on 64-bit hosts) is treated as if it were signed `i64` for three core operations: ordered comparison, right shift, and division/remainder.** All three are silent miscompiles — the program runs, returns the wrong number, and exits 0. Adopters using `u64` for hashing, bit-twiddling, address arithmetic, or any value with the high bit set will get wrong answers without a diagnostic.

The signed-vs-unsigned dispatch is missing at three sites:

1. `tok_to_ir` (line 9805) — folds `<` to a single iop (9 = slt). No type-aware iop split.
2. `emit_cmp` (line 7748) — emits `icmp slt/sgt/sle/sge i64` unconditionally.
3. `>>` lowers to iop 24 (ashr). No `lshr` opcode exists.
4. `/`, `%` route to `__nucleor_panic_div_i64` / `__nucleor_panic_rem_i64`. No `_u64` variants exist; the runtime helper uses signed C `/` and `%`.

These are NOT u64-only theoretical issues — they reproduce on the unmodified shipping `bin/nucleor.exe` with three-line `.nr` programs (see Findings C-001, C-002, C-003 below).

A fourth distinct issue is a misleading diagnostic for compile-time div-by-zero (NUM-021 reports "overflow" instead of "divide by zero"), but that's cosmetic.

Determinism is solid (verify-reproducible PASS on all test inputs). The 6-pass optimizer (`opt_fn`) is observed to be sound where it actually fires; the law-rewrite pass is fail-closed (`law_opt_phase2_proof_validated` returns 0, so `opt_law_rewrite_block` is a no-op — correct conservative posture).

---

## Per-construct coverage matrix

Each construct compiled and observed working, **except where Findings reference**:

| Construct                         | Test          | Result |
|-----------------------------------|---------------|--------|
| Integer literal (i64)             | t02, t06      | PASS   |
| Integer literal (i32)             | t14, t15      | PASS (i32-typed `sadd.with.overflow.i32`) |
| Integer literal (u32)             | t16, t17      | PASS (`uadd.with.overflow.i32`, zext) |
| Integer literal (u64)             | t01, t12, t18 | **FAIL — see C-001/C-002/C-003** |
| Float literal (f64)               | t22, t23      | PASS |
| String literal                    | t01, t08      | PASS (`@.str.N` private constants) |
| `let` binding                     | all           | PASS |
| `if` / `else`                     | t01, t06, t08 | PASS |
| `while`                           | t20, t21      | PASS |
| `match` on enum tag               | t08           | PASS |
| Struct literal + field access     | t08           | PASS |
| Empty struct                      | t13           | PASS |
| Enum variant constructors         | t08           | PASS |
| User fn definition + call         | t04, t05      | PASS (`call i64 @<name>`) |
| Recursive fn                      | t05           | PASS |
| Fn pointer / `fn(i64) -> i64` arg | t09           | PASS (`ptrtoint`/`inttoptr`/indirect call) |
| `print`, `print_int`, `print_bool`| all           | PASS |
| `Vec::new`, `Vec::with_capacity`  | t21           | PASS |
| Deeply nested arithmetic          | t10           | PASS |
| Strict-arith overflow trap (i64)  | t02, t19      | PASS — strict-intrin fires NUM-021 |
| Strict-arith overflow trap (i32)  | t14           | PASS — `sadd.with.overflow.i32` panic path |
| Const div-by-zero (folded)        | t03           | PASS (skip-fold; later strict-intrin trap) — but **see C-005** for diagnostic text |
| Runtime div-by-zero               | t03b          | PASS (`__nucleor_panic_div_i64` clean) |
| Shift OOB at runtime              | t11           | PASS (`__nucleor_panic_shl_i64` clean) |
| NaN equality                      | t23           | PASS (IEEE-correct fcmp behavior) |
| `verify-reproducible`             | t01b, t08     | PASS — byte-identical IR + EXE |
| Bitwise `&` with negative LHS     | t07           | PASS (fold conservatively skips; runtime LLVM `and i64` correct) |

---

## Per-axis coverage

1. **Functional** — covered (all common AST constructs reduced to working IR).
2. **Optimizer correctness** — partially covered. No `--O0` / `--no-opt` flag exists, so a strict diff between optimized and un-optimized cannot be performed from CLI. The const-fold pass was inspected line-by-line (lines 5772-5951); div/mod-by-zero skip-fold (v0.3.145) and bitwise-negative skip-fold (v0.3.147) are correct. Comparison fold uses signed semantics — see C-001.
3. **Edge** — covered (zero-arg fn, recursion, deep nest, empty struct, large vec, NaN, i64::MIN, shift OOB, div by zero).
4. **Adversarial** — covered (u64 high-bit, signed/unsigned divergence, OOB shift, overflow at i64 boundary).
5. **Determinism** — covered (verify-reproducible PASS on multiple programs; `/Brepro` PE flag and `--build-id=none` ELF flag both observed in `host_stack_link_flag`).
6. **Differential** — partial (one Python parity test, t06, four cases all match bit-exact). For u64, no Rust/C reference was compiled — but the LLVM IR itself is the smoking gun (see C-001 IR snippet).
7. **Stage equivalence** — not actively rebuilt (constraint: don't run verify.sh; don't modify seed). The fixed-point script `tools/check_self_host_md5.sh` was read end-to-end; the invariant is correct (md5(stage1.ll) == md5(stage2.ll) == md5(seed.ll)). No issue with the *invariant*; only with the *content* of what gets fixed (a stage1 buggy code can stage2-reproduce its own buggy IR — fixed-point alone doesn't prove correctness).
8. **Linker** — covered (all `__nucleor_*` runtime symbols are `declare`d in `emit_externs`; `host_stack_link_flag` uses `/Brepro` on Windows + `--build-id=none -lm -lpthread` on POSIX; clang resolution probes `C:\Progra~1\LLVM\bin\clang.exe` / `C:\Program Files\LLVM\bin\clang.exe` / MSYS2 path / bare `clang`. Reasonable.).

---

## Findings

### C-001 — **CRITICAL — silent miscompile** — `u64` ordered comparison uses signed `icmp`

**Site:** `compiler/nucleor_s1_compiler.nr` lines 9805 (`tok_to_ir`), 7748–7763 (`emit_cmp`), 7916–7921 (`emit_inst` dispatch), 5839–5851 (constant fold).

**Symptom.** A program that compares two `u64` values whose high bit is set returns the wrong answer. No diagnostic, exit code 0.

**Reproducer (`audit_scratch_codegen/t01b_u64_cmp_runtime.nr`):**
```
fn make_high() -> u64 { return 9223372036854775808u64; }
fn make_one()  -> u64 { return 1u64; }
fn main() -> i64 {
    let h: u64 = make_high();
    let o: u64 = make_one();
    if h < o { print("signed_lt_yes"); } else { print("signed_lt_no"); };
    return 0;
}
```
Observed: prints `signed_lt_yes`. Expected (unsigned): `signed_lt_no` (since 9223372036854775808 > 1 in u64).

**Root-cause IR snippet** (from `target/t01b_u64_cmp_runtime.ll`):
```
  %r.6.cmp = icmp slt i64 %r.4, %r.5
```
The `slt` (signed less-than) is hard-coded in `emit_cmp`. There is no signedness-aware iop. `tok_to_ir` maps `<` to iop 9 unconditionally; `is_cmp_or_logic` accepts iops 7–14 and routes them all through `ir_cmpop` → `emit_cmp` → `slt`/`sgt`/`sle`/`sge`.

The constant-fold pass (`opt_fold_block` lines 5839–5851) has the same defect: `if va < vb { result = 1; }` uses Nucleor's i64 `<` (signed) on operands stored in cmap as i64. Fold result == runtime result; both wrong.

**Severity.** CRITICAL — silent miscompile of a documented language type. Any code using `u64` for hashing, monotonic counters, address arithmetic, time stamps, or wide bit fields can produce wrong answers without a diagnostic.

**Why u32 is not affected.** u32 zero-extends to i64 (`zext i32 X to i64`), so the high i64 bit is always 0 and `slt` agrees with `ult`. u8 / u16 same. Only u64 (and usize on 64-bit hosts when used as an unsigned magnitude > i64::MAX) exposes the divergence.

**Remediation recommendation.**
- Add a parallel `iop` set for unsigned comparison (e.g. iops 38–43 for ult/ugt/ule/uge plus eq/ne which already work on raw bits). Map `<`,`>`,`<=`,`>=` at *type-checking time* (not at `tok_to_ir` time, since the lexer doesn't know operand types) — a `lower_bin_cmp(lt, rt, op)` helper that picks signed vs unsigned iop based on operand types.
- For mixed-type comparisons: the type checker should already promote / reject; verify that path doesn't paper over.
- Update the constant-fold table (lines 5839–5851) with a parallel unsigned branch — for unsigned, treat the i64 cmap value as `u64` via `unsigned_lt(va, vb)` etc. (Nucleor doesn't have `as u64` from i64 cmap; can compute `(va ^ MSB) < (vb ^ MSB)` to sort-by-unsigned in signed space, or via `wrapping_sub` and sign-of-result; either way an explicit helper.)
- Add a test fixture: `tests/features/integers_u64_compare.nr` with `assert_eq!(0x8000_0000_0000_0000u64 > 1u64, true);`.

---

### C-002 — **CRITICAL — silent miscompile** — `u64` right-shift uses `ashr` (sign-extending)

**Site:** `compiler/nucleor_s1_compiler.nr` line 7926 (`else if op == 24 { emit_arith(sb, "ashr", ...) }`); `tok_to_ir` line 9822 (token 116 `>>` → iop 24).
**Runtime:** `stdlib/runtime/nucleor_llvm_rt.c` line 4727 (`__nucleor_panic_shr_i64` does `a >> (int)b` on `long long a` — implementation-defined-but-usually-arithmetic shift).

**Symptom.** `u64 >> n` for a `u64` with the high bit set gets sign-extended.

**Reproducer (`audit_scratch_codegen/t12_unsigned_shr.nr`):**
```
fn make_high() -> u64 { return 9223372036854775808u64; }  // bit 63 set
fn make_one()  -> u64 { return 1u64; }
fn main() -> i64 {
    let h = make_high(); let n = make_one();
    let r: u64 = h >> n;
    print_int(r as i64); print("\n");
    return 0;
}
```
Observed: prints `-4611686018427387904` (= `0xC000_0000_0000_0000`, ashr).
Expected (lshr): `4611686018427387904` (= `0x4000_0000_0000_0000`).

**Root-cause IR snippet** (from `target/t12_unsigned_shr.ll`):
```
  %r.7 = call i64 @__nucleor_panic_shr_i64(i64 %r.5, i64 %r.6)
```
…and the runtime helper at `nucleor_llvm_rt.c:4727` uses signed `>>`.

**Severity.** CRITICAL — silent miscompile. Bit-twiddling code (CRC, hash mixing, SIMD-emulation, byte-extraction from u64) is wrong.

**Remediation recommendation.**
- Introduce iop 25 for `lshr` (currently unused — only 23/24 are taken for shl/ashr). At lowering time, choose iop 24 (ashr) for signed types and iop 25 (lshr) for unsigned types.
- `emit_inst` adds `else if op == 25 { emit_arith(sb, "lshr", ...); }`.
- Add `__nucleor_panic_shr_u64` runtime helper using `(unsigned long long)a >> b` (already exists in pattern from `panic_shl`'s use of `(unsigned long long)a << b`).
- Route the shift dispatch in lowering (`compiler/nucleor_s1_compiler.nr` near line 27139) by signedness of LHS type.
- Test: `tests/features/integers_u64_shift.nr`.

---

### C-003 — **CRITICAL — silent miscompile** — `u64` division and remainder use signed `sdiv` / `srem`

**Site:** lowering line 27170 (`if iop == 5 { sh = "panic_div"; }`) and 27171 (rem). Always routes to `__nucleor_panic_div_i64` / `__nucleor_panic_rem_i64`. No `_u64` runtime helper exists.

**Symptom.** `u64 / u64` and `u64 % u64` use signed semantics when either operand has the high bit set.

**Reproducer (`audit_scratch_codegen/t18_u64_div.nr`):**
```
fn make_huge() -> u64 { return 18446744073709551614u64; }  // 2^64 - 2
fn make_two()  -> u64 { return 2u64; }
fn main() -> i64 {
    let n = make_huge(); let d = make_two();
    let q: u64 = n / d;
    print_int(q as i64); print("\n");
    return 0;
}
```
Observed: prints `-1`.
Expected: `9223372036854775807` (= 2^63 - 1).

**Root-cause IR snippet:** `%r.7 = call i64 @__nucleor_panic_div_i64(i64 %r.5, i64 %r.6)`. The runtime helper does signed `/`. `(long long)18446744073709551614` reinterprets to -2; `-2 / 2 = -1`. Wrong.

**Severity.** CRITICAL — silent miscompile.

**Remediation recommendation.**
- Add `__nucleor_panic_div_u64(unsigned long long, unsigned long long)` and `__nucleor_panic_rem_u64` runtime helpers. They should panic on `b==0` and otherwise return `a / b` / `a % b` on the unsigned types.
- In the lowering site (~line 27170), pick the helper name based on operand signedness (the same `binop_u64_type` helper already used for u64 add/sub/mul at line 27117 is the natural signal — extend the v0.4.886 mechanism to div/rem).
- Note: this also affects i64 / -1 overflow (`LLONG_MIN / -1` is UB in LLVM). The signed helper at `nucleor_llvm_rt.c:4740` does check for that case in `checked_div_i64`, but I did not verify `__nucleor_panic_div_i64` does — recommend confirming as part of the same fix.
- Test: `tests/features/integers_u64_divmod.nr`.

---

### C-004 — **HIGH — optimizer-vs-runtime semantic agreement (subtle)** — bitwise fold with negative operand is silently skipped, masking a divergence-finder regression

**Site:** `opt_fold_block` lines 5887–5947.

The fold for `&`/`|`/`^` is skipped if either operand is negative (v0.3.147 fix). The runtime LLVM `and i64` produces the correct bitwise answer. The skip is conservative and produces no miscompile *today*. **However**, this means a `255 & (-1)` constant-folded comparison (e.g. asserting fold == runtime path) cannot detect future regressions in the runtime path because the fold path doesn't compute. The current solution sacrifices fold coverage for safety; it works.

**Severity.** HIGH (was CRITICAL pre-v0.3.147; current state is conservative-correct but hides re-emergence of the original issue from automated checks).

**Remediation recommendation.**
- Reimplement the bitwise fold without the `(ra/2)*2` LSB-extraction trick that broke on negative LHS. Possible options:
  (a) Cast i64 → emulated u64 via `if v < 0 { v = wrapping_add(v, 1); v = 0 - v - 1; }` — i.e. compute `~v` via two's complement identity, then bit-extract on the (now non-negative) bitwise complement, then re-complement.
  (b) Add a runtime helper `__nucleor_const_and_i64(i64, i64) -> i64` that does the bitwise AND in C and let the fold call it (but s1 fold runs at compile time inside the compiler; this would require linking the helper into the compiler binary — simpler is option a).
  (c) Add bit-shift-based extraction using the existing `>>` (iop 24, ashr) — pre-fix is to first do `(v >> k) & 1` style which avoids signed division. ashr of negative still preserves sign in upper bits, but `& 1` on the result extracts only the LSB, which is correct.
- Add fixture: `tests/features/integers_bitwise_fold_neg.nr` checking const-fold and runtime path produce identical results for `(-1) & 0xFF`, `0xFF & (-1)`, `(-3) | 5`, etc.

---

### C-005 — **MEDIUM — diagnostic** — compile-time `100 / 0` reports as NUM-021 "integer overflow"

**Site:** the strict-intrin compile-time evaluator. Reproducer `audit_scratch_codegen/t03_div_zero_const.nr`:
```
fn main() -> i64 { let z: i64 = 0; let r: i64 = 100 / z; print_int(r); return 0; }
```
Output:
```
error[NUM-021]: integer constant expression for let-binding `r` overflows i64 at compile time. ...
```
The message says "overflows i64" but the actual condition is divide-by-zero (a different class of error). NUM-009 is the documented div-by-zero literal code.

**Severity.** MEDIUM — adopter confusion; correct diagnostic exists (NUM-009) but isn't routed when div-by-zero appears via constant-propagation rather than a literal RHS.

**Remediation recommendation.**
- In whatever pass emits NUM-021 for the const-folded result of `100 / z` (where z propagated to 0), add a precondition check: if the RHS const-folds to 0 *and* the operator is `/` or `%`, emit NUM-009 instead with a "the divisor was const-propagated from `z = 0` at line N" hint.

---

### C-006 — **MEDIUM — IR quality (cosmetic, deterministic, no miscompile)** — every `const_int` materializes as `add i64 K, 0`

**Site:** line 7910:
```
if op == 0 { sb_append(sb, "  %r."); ...; sb_append(sb, " = add i64 "); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n"); }
```
LLVM cleans this up at -O1+, but the emitted IR is non-canonical. Constants should ideally be inlined where used or emitted as zero-cost SSA values via `bitcast`/direct use. The current pattern bloats the IR by ~2 lines per constant and adds a register pressure point pre-instcombine.

**Severity.** MEDIUM (IR quality; performance is reclaimed by later LLVM passes; no correctness or determinism impact).

**Remediation recommendation.**
- Change `emit_inst` op 0 to fold the constant directly into the consuming instruction (i.e. defer materialization to use-site). Requires a small rework where `emit_arith`/`emit_cmp`/etc. accept a "this operand is a known constant" hint.
- Less invasive alternative: leave the `add i64 K, 0` pattern but add a trivial peephole in `opt_fold_block` to stitch consumers' operands directly to the constant when there's only one consumer. (The current opt_fold has the cmap; extend it to rewrite consumers' op1/op2 references when the source is a const.)

---

### C-007 — **MEDIUM — comparison fold is signed-only**

**Site:** `opt_fold_block` lines 5839–5851. As noted in C-001, the fold uses `va < vb` etc. on i64 cmap entries with signed semantics. Fold and runtime agree (both wrong for u64). Listed separately because the **fix locus** is the optimizer, not just the lowering — when C-001's signedness-aware iops are added (38–43), this fold table needs the parallel branch.

**Severity.** MEDIUM (rolled into C-001 fix; no independent reproducer beyond t01).

**Remediation recommendation.**
- After C-001 introduces unsigned iops, add fold cases for them with explicit unsigned comparison logic (XOR-with-MSB trick or computed via wrapping subtraction sign-of-result).

---

### C-008 — **NOTE — observation** — fixed-point self-host is necessary but not sufficient

**Site:** `tools/check_self_host_md5.sh` (read end-to-end; not run).

The script checks `md5(stage1.ll) == md5(stage2.ll) == md5(bootstrap_seed.ll)` under `NUCLEOR_INT_STRICT_INTRIN=1`. This guarantees the compiler reproduces its own IR shape across rebuilds. **It does not** guarantee the IR shape is *correct* — a stage1 with a subtle codegen bug will produce a stage2 binary with the same bug, fixed-pointing happily. The user-source spot check (`feedback_nucleor_self_host_validation.md`) is the documented mitigation.

**Severity.** NOTE (architectural observation; not actionable as a bug).

**Remediation recommendation.**
- Augment the spot-check protocol with a `tests/features/integers_u64_*.nr` triple that explicitly asserts u64 correctness via runtime panics (`if (h >> 1) != expected { panic(); }`). Once C-001/C-002/C-003 land, those tests will catch any future regressions even if the seed re-locks.

---

### C-009 — **NOTE — observation** — `bin/nucleor.exe` accepts no `--O0` / `-fno-fold` flag

The 6-pass optimizer (`opt_fn`) cannot be disabled from the CLI. This makes pure differential testing of "opt-on output == opt-off output for all programs" impossible from the public interface. The internal cmap-based fold/prop/dse/dce/cse/law passes were instead read line-by-line.

**Severity.** NOTE.

**Remediation recommendation.**
- Add `--no-opt` (or `-O0`) to `nucleor.exe`. Internally, gate the body of `opt_fn` on a flag set from CLI parsing. Useful for adopter bug reports ("does the bug repro under -O0?") and CI differential testing.

---

## Constructs/axes NOT covered (next pass)

- Generics monomorphization codegen (no test in this pass — out of recon scope)
- Trait method dispatch (vtable / dyn-box codegen — runtime helpers `dyn_box_*` exist; not exercised)
- Closure capture by reference vs value (only fn-pointer test ran)
- WASM and PTX backends (out of x86_64 scope)
- `build-shared` (DLL/.so export ABI)
- `--provenance` flag content embedding (placeholder only validated)
- `auto_drop` / `manual_drop` insertion correctness in IR (RFC-0062 territory; cross-layer with borrow checker)
- Atomic ordered builtins (`emit_atomic_ordered_call` at line 5428 — not exercised)
- f8e4m3 / f8e5m2 / f16 / bf16 codegen (mapped types but not run)
- i128 / u128 codegen path (LLVM accepts but fold pass uses i64 cmap — likely an additional silent-miscompile zone for i128 that wasn't reproduced this pass)

## Summary table

| ID    | Severity   | Class                  | Fix locus                         |
|-------|------------|------------------------|-----------------------------------|
| C-001 | CRITICAL   | u64 ordered cmp = slt  | tok_to_ir + emit_cmp + fold       |
| C-002 | CRITICAL   | u64 `>>` = ashr        | tok_to_ir + emit_inst op==24      |
| C-003 | CRITICAL   | u64 div/rem = signed   | lowering line 27170 + runtime rt  |
| C-004 | HIGH       | bitwise fold conservative | opt_fold_block line 5887       |
| C-005 | MEDIUM     | NUM-021 misnamed       | strict-intrin diagnostic emitter  |
| C-006 | MEDIUM     | const_int IR quality   | emit_inst op==0                   |
| C-007 | MEDIUM     | cmp fold signed-only   | opt_fold_block lines 5839–5851    |
| C-008 | NOTE       | fixed-point sufficient | test fixtures, not compiler       |
| C-009 | NOTE       | no `-O0` flag          | CLI parsing                        |

---

End of audit.
