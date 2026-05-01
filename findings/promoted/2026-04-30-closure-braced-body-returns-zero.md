---
title: Closure with braced body `|y| { expr }` silently returns 0; the unbraced form `|y| expr` is correct
severity: silent-miscompute
probe_file: probes/closures/closure_brace_vs_expr.nr
diagnostic_actual: none (compile clean, runtime returns 0)
diagnostic_expected: parity between `|y| expr` and `|y| { expr }` — both should evaluate to the body's tail expression
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: CLOSED in v0.4.204 — closure handler at line 16168 now mirrors lower_fn's tail-expr detection; regression-guard fixture at tests/features/closure_braced_body_tail_expr.nr locks in 6 closure-body shapes
---

## Repro

```nr
fn main() -> i32 {
    let f1 = |y: i32| y + 7;
    let f2 = |y: i32| { y + 7 };
    print_int(f1(10));   // prints 17
    print_int(f2(10));   // prints 0   <-- silent miscompute
    0
}
```

## Actual

```
$ ./target/closure_brace_vs_expr.exe
17
0
```

`f1` and `f2` should be semantically identical: both close over zero
state and return `y + 7`. `f1` (expression-bodied) returns 17 correctly.
`f2` (block-bodied) returns 0 — as if the closure is being treated as
void-returning and the call site picks up the v0.4.156 closure-void-as-0
path.

## Expected

`f2(10)` returns 17. The two forms are equivalent in Rust and the
existing `tests/features/closure_basic.nr` fixture uses the
expression-bodied form (works), but adopters copying typical Rust idiom
will write `|args| { body }` and silently get 0.

## Why this matters

This is a beginner-grade footgun. Any adopter writing:

```nr
let scale = |v: f64| { v * 2.0 + 1.0 };
let r = scale(3.0);   // r == 0.0  ←  user's calculation lost
```

…gets `0` with no signal. The pattern matches the v0.4.156 hazard class
(TYP-021 ext: closure call returning void silently bound the lhs)
exactly, except here the closure isn't void — its body is `y + 7` /
`v * 2.0 + 1.0` — the codegen is treating it AS IF it were void.

## Suspected location

The closure body lowering. The expression-bodied form (no braces)
probably reaches a codegen branch that returns the body expression
directly. The block-bodied form reaches a stmt-block lowering that
discards the tail expression instead of returning it. Possibly the same
miswiring that `let mut x = { ... };` had earlier (block-tail returned
correctly there because the let-RHS lowering snags it).

Recommended grep: closure-body lowering site that distinguishes
"expression body" vs "block body" — the block path likely calls a
stmt-list emitter that doesn't capture the tail.

## Severity

silent-miscompute. No diagnostic, wrong runtime output, hits canonical
Rust idiom. Recommend prioritizing alongside the push-during-iter
unbounded-mem finding for the next ship after v0.4.163.

## Cross-ref

- v0.4.156 (TYP-021 ext: closure call returning void silently bound lhs).
  Same hazard family; this finding is the body-form sibling.
- `tests/features/closure_basic.nr` uses the working expression-bodied
  form and passes verify.


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.204**.
- Regression-guard fixture: `tests/features/closure_braced_body_tail_expr.nr`.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
