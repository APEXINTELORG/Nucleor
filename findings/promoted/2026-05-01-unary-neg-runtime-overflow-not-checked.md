---
title: Unary `-` (negation) does NOT check for runtime overflow on i64. `-i64::MIN` silently wraps to i64::MIN. Asymmetric with `+`/`*` (PANIC) and compile-time const-fold (PANIC). Means hand-written `abs()` or `if x<0 { -x }` patterns silently miscompute on i64::MIN.
severity: silent-miscompute (asymmetric overflow check)
probe_file: probes/numeric/unary_neg_overflow.nr (probe-branch)
diagnostic_actual: pre-fix — build + run succeed; `neg(-9223372036854775808)` returns i64::MIN (wrap).
diagnostic_expected: PANIC at runtime, matching `+`/`*` overflow behavior.
discovered_against: main v0.5.25 (probe rebased)
commit: probe (post-rebase) + main ee5d7e4b
status: CLOSED in v0.6.43 — kind-5 (unary minus) lower now consults NUCLEOR_INT_STRICT_INTRIN (default "1"), routing `-x` for i64 through panic_neg by default. Symmetric with `+`/`*` overflow check.
---

## Closure (main agent v0.6.43)

`compiler/nucleor_s1_compiler.nr` kind-5 (unary minus) lowering
(line ~19326) — pre-fix only consulted `NUCLEOR_INT_STRICT_ARITH`
(default `""`, opt-in). v0.6.43 also consults
`NUCLEOR_INT_STRICT_INTRIN` (default `"1"`, opt-out) — same env
var that defaults `+`/`*` to panic-checked. When either is `=1`,
unary-neg routes through `panic_neg`. With `_INTRIN=0`, legacy
native-sub path restored.

The runtime helper `__nucleor_panic_neg_i64` was already
implemented (panic-on-i64::MIN); only the compiler-side dispatch
was missing.

## Adopter migration

```nucleor
fn neg(x: i64) -> i64 { -x }
fn main() -> i32 {
    let r: i64 = neg(-9223372036854775808);
    // Pre-v0.6.43: r = -9223372036854775808 (silent wrap)
    // v0.6.43: PANIC: i64 neg overflow: -(i64::MIN)
    print_int(r as i32);
    0
}
```

For wrapping behavior:
```bash
NUCLEOR_INT_STRICT_INTRIN=0 nucleor build foo.nr
```

## Forward-roadmap (narrow widths)

This ship covers i64 only. i32/i16/i8 unary-neg overflow on the
respective MIN values is not yet checked. Follow-up ship can
add `panic_neg_i32` / `panic_neg_i16` / `panic_neg_i8` runtime
helpers and dispatch them from the kind-5 lower based on the
operand's narrow type. Same pattern as the existing narrow-div
helpers (panic_div_i32 etc.) added in v0.5.10.

## Promoted

- Fixture: `tests/fixtures/v0643_unary_neg_min_panics.nr`.
- verify.sh step: `v0643_unary_neg_min_panics`.
- Fix shipped: v0.6.43 (i64 only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
