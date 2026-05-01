---
title: `i32::MIN / -1` exits with raw Windows STATUS_INTEGER_OVERFLOW exception (rc=-1073741675), not the Nucleor PANIC family — adopter sees an uninterpretable exit code instead of a clean diagnostic. Sister `i64::MIN / -1` panics correctly.
severity: silent-miscompute / wrong-error (asymmetric runtime behavior between i32 and i64)
probe_file: probes/numeric/i32_min_div_neg_one.nr (will be filed)
diagnostic_actual: `nuc run: child exited rc=-1073741675` (= 0xC0000095 = STATUS_INTEGER_OVERFLOW) — Windows-level exception, no Nucleor-side message
diagnostic_expected: `PANIC: integer overflow` (matching i64::MIN/-1 + matching env-ON strict-intrin behavior on overflow)
discovered_against: main v0.5.8
commit: probe 973c4fa + main 2f8fda0
---

## Repro

```nr
fn main() -> i32 {
    let a: i32 = 0 - 2147483648;   // i32::MIN
    let b: i32 = 0 - 1;             // -1
    print_int(a / b);                // i32 / i32 — result overflows
    0
}
```

## Actual

Both env-OFF and env-ON (NUCLEOR_INT_STRICT_INTRIN=1):

```
nuc run: child exited rc=-1073741675 from target\strict2_signed_min_div.exe
```

`-1073741675 = 0xC0000095 = STATUS_INTEGER_OVERFLOW` — Windows
catches the x86 IDIV exception and aborts the process. No
Nucleor PANIC message; adopter has no way to interpret the
exit code without a Windows-exception decoder.

## Sister case works correctly

The i64 version of the same overflow:

```nr
let a: i64 = 0 - 9223372036854775808;
let b: i64 = 0 - 1;
print_int((a / b) as i32);
```

Output:
```
PANIC: integer overflow
nuc run: child exited rc=1
```

Clean PANIC + rc=1, matches the rest of the Nucleor overflow-handling family.

## Hazard tier

Wrong-error / silent-miscompute. Adopter writing canonical i32 arithmetic that hits the INT_MIN/-1 corner sees a Windows-exception exit code with no source-level diagnostic. The Nucleor narrow-arith strict-intrin substrate (Track E, v0.4.234-235) added overflow checks for i32/i16/i8 add/sub/mul, but **division** at i32 width either:
1. Lowers to a raw `sdiv i32` without the intrinsic-overflow guard, OR
2. Uses the intrinsic but the intrinsic isn't actually recognized for the INT_MIN/-1 case at i32 width

…and falls through to the Windows IDIV trap.

## Suspected fix area

Compiler i32 division lowering. Either:

**A — emit the i32 overflow check explicitly.** Pre-divide:
- `if a == i32::MIN && b == -1 { panic("integer overflow"); };`
- This matches what the i64 path appears to do (since the i64
  case PANICs cleanly).

**B — use the LLVM `@llvm.sdiv.fix.i32` or wrap idiv in a
runtime helper** that handles the INT_MIN/-1 corner.

Recommended: **A** mirrored from the i64 path. The i64 case works
because the runtime helper `__nucleor_div_i64` (or similar) does
the explicit corner-case check.

## Memory-blow-up note

Not memory-related. Runtime correctness gap.

## Cross-ref

- v0.4.234/235 — Track E narrow-intrinsic substrate; covered i8/i16/i32 add/sub/mul overflow but apparently missed division
- v0.4.238 — Track F strict-mode default flip; this hazard fires under both env-OFF and env-ON
- The i64 reference behavior: clean PANIC at runtime — should be the i32 model

## Probe

`probes/numeric/i32_min_div_neg_one.nr` — minimal repro (will be filed).


## Promoted

- Fixtures:
  - `tests/err/err_i32_min_div_neg_one.nr` — `i32::MIN / -1`
    runtime panic; expects "PANIC: i32 div overflow: i32::MIN / -1"
    on stderr and rc=1 (was rc=-1073741675 on Windows pre-fix).
  - `tests/features/narrow_div_panic_overflow.nr` — positive
    coverage for normal i32/i16/i8 div+rem (no false panic);
    exit 0 with correct truncating-int results.
- Fix shipped: v0.5.10 — runtime + compiler.
  - **Runtime** (`stdlib/runtime/nucleor_llvm_rt.c`): six new
    helpers `__nucleor_panic_div_iN` and `__nucleor_panic_rem_iN`
    for N in {32, 16, 8}. Each takes i64 args (sign-extended per
    the call-site ABI), truncates to native iN, checks zero +
    iN_MIN/-1, panics on overflow, returns i64.
  - **Compiler** (`compiler/nucleor_s1_compiler.nr`):
    1. Six new IR `declare` lines in the runtime header (mirrored
       in `compiler/nucleor_tools_suite.nr`; drift gate
       enforces).
    2. Six new name-resolver mappings for `panic_div_i{32,16,8}`
       and `panic_rem_i{32,16,8}` (mirrored in tools-suite).
    3. New early-exit branch in `lower_expr_narrow`'s arith-op
       block: when `iop == 5 || iop == 6` (div/rem) AND `tw > 0`
       (signed narrow), call the width-specific panic helper
       instead of falling through to the saturating helper or
       raw `sdiv iN`. Unsigned narrow paths (tw < 0) keep raw
       `udiv` since there's no MIN/-1 trap for unsigned widths.
- Verify gate: existing per-feature loop picks up the new
  fixture; existing per-err loop picks up the err fixture. The
  err fixture's runtime stderr expectation is exercised by the
  err-loop's exit-code-and-diagnostic check.
- Sister gap (i64 already had this; v0.4.95 ship). v0.5.10
  brings i32/i16/i8 to parity.
- IR fixed-point note: this ship adds 6 new IR `declare` lines.
  Round-1 (old bin frozen IR-declare set) → round-2 (new
  declares emitted) → round-3 (new bin compiles itself again).
  Round-2 == round-3 fixed-point holds; round-1 vs round-2
  diverges by exactly the 6 new declare lines, as expected for
  any new-runtime-helper ship.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on
  origin/probe/exploration commit 930463c).
