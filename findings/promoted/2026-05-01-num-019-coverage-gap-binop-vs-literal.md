---
title: NUM-019 (negative literal in unsigned binding) fires for `let a: u32 = -5;` but NOT for the equivalent `let a: u32 = 0 - 5;` — coverage gap on the binop-expression form.
severity: silent-miscompute (NUM-019 coverage gap)
probe_file: probes/numeric/num_019_binop_evasion.nr (probe-branch)
diagnostic_actual: pre-fix — `let a: u32 = 0 - 5;` builds clean; runtime stores -5 in the u32 binding (two's-complement-wraps to u32::MAX-4).
diagnostic_expected: NUM-019 emit matching the literal form (or a sister NUM-NNN naming the binop-evaluates-negative case).
discovered_against: main v0.5.18 (probe af6cf4c)
commit: probe af6cf4c + main f50a0f94
status: CLOSED in v0.6.45 — let-binding NUM-019 site folds the init expression via `const_i64_expr` when the binding is unsigned; emits NUM-019 if the result is negative.
---

## Closure (main agent v0.6.45)

`compiler/nucleor_s1_compiler.nr` let-binding NUM-019 site (line
~17415) — when the binding is unsigned (signedness == 2), folds
the init expression via `const_i64_expr` and emits NUM-019 if
the result is negative. Skips kind-5 (handled by existing
literal-form check) and kind-1 (covered by NUM-002 literal-out-
of-range).

The const-fold is the same machinery NUM-008 (shift bound) and
NUM-009 (div-by-zero) already use, so detection works for any
arithmetic expression that const-folds to a negative i64 — `0 -
5`, `1000 - 2000`, `(-1)`, etc.

## Adopter migration

```nucleor
// Pre-v0.6.45: silent two's-complement wrap
let a: u32 = 0 - 5;        // a = 4294967291 (u32::MAX-4)
let b: u32 = 1000 - 2000;  // b = 4294966296 (typo'd: meant 2000-1000)

// v0.6.45: NUM-019 halts at compile time for both
//
// Workarounds:
let a: u32 = (0 - 5) as u32;   // explicit cast (intentional wrap)
let a: i32 = 0 - 5;            // signed binding holds -5
let a: u32 = 5 - 0;            // non-negative result
```

## Promoted

- Fixture: `tests/err/err_num019_binop_negative_unsigned.nr`.
- Fix shipped: v0.6.45.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
