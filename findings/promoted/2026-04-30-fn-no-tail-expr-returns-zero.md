---
title: `fn f() -> T { stmt; stmt; }` (no tail expression) silently returns alloca-zero instead of erroring
severity: silent-miscompute
probe_file: probes/arith/fn_no_return_at_all.nr
diagnostic_actual: none
diagnostic_expected: hard error — fn body lacks a tail expression matching declared return type
discovered_against: v0.4.162 (commit 213fee9)
commit: 213fee9e84101dad4a06807f994413d7d4f1cb86
status: PARTIAL CLOSE in v0.4.219 — Repros 1 + 2 (last stmt is kind 20 let-stmt or kind 21 assign, no top-level return, RHS not always-returning) now halt with TYP-026. Repro 3 (kind 25 expr-stmt with `;` consumed by parse_stmt) still silently returns the value of the discarded expression — this case requires AST-level `;` tracking which is out of scope for this ship. Allow-listed: legitimate early-return-via-let patterns like `let v: T = match { Ok(x) => return x, Err(_) => return -1 };` (test t367_question_op_chain.nr) where the let RHS is an always-returning match. Also handles if-with-both-arms-returning. Conservative scope: only kinds 20/21 last; loops/while/for paths skipped to avoid false positives.
---

## Repro 1: no return-shaped statement at all

```nr
fn nothing_returned() -> i32 {
    let _z: i32 = 5;
}

fn main() -> i32 {
    print_int(nothing_returned());   // prints 0  ← silent
    0
}
```

## Repro 2: trailing semicolon discards the value, then more statements run

```nr
fn double(x: i32) -> i32 {
    x * 2;                  // this is a stmt (trailing semi); value discarded
    let _z: i32 = 99;        // alloca-zero return slot survives
}

fn main() -> i32 {
    print_int(double(7));   // prints 0  ← silent
    0
}
```

## Repro 3: trailing semicolon, no further statements (exposes alloca-leak)

```nr
fn double(x: i32) -> i32 {
    x * 2;
}

fn main() -> i32 {
    print_int(double(7));   // prints 14  ← misleading, alloca happened to land
    0
}
```

## Actual

All three compile clean. Runtime returns 0 (Repros 1 and 2) or 14 (Repro
3, which is *fortuitous* — the alloca slot for the return value happens
to hold the discarded `x * 2`'s value). All three should be hard
compile-time errors.

## Expected

A TYP-NNN diagnostic at the fn-body type-check:

```
error[TYP-NNN]: fn `nothing_returned` declared to return `i32` but body has no tail expression of that type.
  --> fn nothing_returned@line 1:4
```

This is the same hazard class as v0.4.126 (TYP-016 closed `let x: i64 =
if false { 5 };` returning the alloca's zero-init slot). Here the
analogous case is the fn-body's return slot — pre-fix the body never
writes the return alloca, and the caller reads `0` (or worse, leaked
register-state from an unrelated computation).

## Severity

silent-miscompute. The fortuitous Repro-3 case (returns 14 by
coincidence) is the most dangerous: a developer writing
`fn f() -> i32 { x * 2; }` may run their tests, see plausible output,
and ship. Then a future refactor that adds a stmt after the implicit
"return" (Repro 2) flips the alloca and the program silently returns 0.

The void-fn case is fine (`fn f() -> () { stmt; }` should not error),
so the check needs to fire only when the declared return type is
non-void AND the body has no terminating tail-expr / explicit return.

## Suspected location

The fn-body type-check / lowering. Add a check at fn close-brace:

```
if declared_return_type != "void" && !body_has_tail_expr_or_explicit_return {
    type_diag("TYP-NNN", "fn declared to return T but body has no tail expression of that type");
}
```

Body-has-tail-expr is computable from the AST (the last node in the
fn-body block) — it's a tail expression if and only if it's an Expr
node, not a Stmt node (Stmt nodes have trailing `;`).

## Cross-ref

- v0.4.126 (TYP-016: `if` without `else` zero-init): same hazard
  family, sister fix-shape.
- v0.4.155 (TYP-008 ext: `let mut x: T;` no init): same hazard
  family — uninit-binding silent-zero.
- v0.4.156 (TYP-021 ext: closure call returning void silently bound):
  same hazard family — implicit-void coerced to 0.

This finding is the **fn-decl** sibling of all three.

## Probably-also-closes

The pre-existing baseline FAILs `lang/closures` and
`runtime/concurrency` reference TYP-014 in their error output, but a
quick read of those fixtures may show they ALSO use a tail-less fn body
that's leaking through the alloca path. If so, fixing this finding
narrows the baseline-FAIL set further.


## Promoted

- Status frontmatter: see top of file. Closure version: **v0.4.219**.
- Verify gate: existing per-feature loop picks up the fixture above.
- Promoted: 2026-04-30 by main agent (footer backfilled 2026-05-01 per probe-agent Q3 footer-shape uniformity request).
