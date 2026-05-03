---
title: v0.6.12 closes `(expr)(args)` for kind-9 (field) / kind-10 (index) / kind-8 (method-call) inner expressions but THREE OTHER inner-expression shapes still silently miscompute the original way (return fn-pointer ADDRESS instead of calling) — (1) IIFE closure call `(|x| x*2)(21)`, (2) call result `(get_handler())(21)`, (3) cast `(p as fn(i64)->i64)(21)`. All three print giant address-like numbers (140703...) where adopters expect the call result.
severity: silent-miscompute (sister to v0.6.12 closure)
probe_file: probes/types/paren_call_residuals.nr (probe-branch)
diagnostic_actual: pre-fix — build + run succeed; output is the inner expression's i64 representation (e.g. `140703114530880`) rather than the call result.
diagnostic_expected: clean halt mirroring v0.6.12's diag for kind-9/10/8 (`ERROR: (expr)(args) direct-call form not yet supported`).
discovered_against: main v0.6.12 (probe rebased)
commit: probe (post-rebase) + main dcf2490f
status: CLOSED in v0.6.28 via three extra inner-kind branches in parse_primary tt==50 paren branch.
---

## Closure (main agent v0.6.28)

`compiler/nucleor_s1_compiler.nr` parse_primary tt==50 paren
branch — sister `if` adjacent to v0.6.12's kind-9/10/8 halt:

```nucleor
if inner_kind == 42 || inner_kind == 7 || inner_kind == 99 {
    print("ERROR: `(expr)(args)` direct-call form not yet supported for IIFE / call-result / cast inner expressions …");
    print("  IIFE:        let f = |x: i64| x * 2; let v = f(21);");
    print("  Call result: let f = get_handler();    let v = f(21);");
    print("  Cast:        let f = p as fn(i64)->i64; let v = f(21);");
    panic(…);
};
```

Halts with the same workaround-pointer shape as v0.6.12. Real
indirect-call lowering (extending parse_postfix to accept
`(args)` on any callable expression + emit indirect-call IR via
inttoptr + call) remains the multi-ship forward fix.

## Adopter migration

All three workarounds are supported today and produce the
expected call result:

```nucleor
// IIFE
let f = |x: i64| x * 2;
let v = f(21);                  // 42 — works.

// Call result
let f = get_handler();
let v = f(21);                  // 42 — works.

// Cast
let f = p as fn(i64) -> i64;
let v = f(21);                  // 42 — works.
```

## Hazard tier closed

Sister silent-miscompute to v0.6.12. With this ship + v0.6.12,
all six inner-expression shapes that the parser would silently
swallow (`(expr)(args)`) now halt cleanly — no surface remaining
for adopters to hit a giant address-like number.

## Forward-roadmap

Real indirect-call lowering for the canonical Rust direct form
needs:
- parse_postfix to recognise `(args)` after any callable
  expression (currently only after kind-3 var-refs).
- Lower-pass to emit `inttoptr + call` for the non-direct case.
- Type-checker to enforce the inner expression's type is
  `fn(...) -> R`.

Substantial. Deferred to a post-v0.6 RFC.

## Promoted

- Fixtures: `tests/err/err_paren_call_iife_residual.nr`,
  `tests/err/err_paren_call_callresult_residual.nr`,
  `tests/err/err_paren_call_cast_residual.nr`.
- Fix shipped: v0.6.28.
- Promoted: 2026-05-02 NIGHT by main agent (probe commit on
  `origin/probe/exploration`).
