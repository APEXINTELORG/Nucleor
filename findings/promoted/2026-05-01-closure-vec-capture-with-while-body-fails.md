---
title: `Vec<closure>` indexed-call inside `while` body fails — TYP-005 or silent wrong-output depending on capture shape
severity: silent-miscompute (closure-in-Vec limitation)
probe_file: probes/closures/closure_vec_in_while.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-005 or silent wrong output
diagnostic_expected: indexed Vec<closure> call inside while body works
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — bundled with `2026-05-02-closure-capture-broken-inside-while-and-loop-bodies` and `2026-04-30-closure-cant-call-sibling-closure`. Same closure-capture-flow root cause; same v1 borrow-checker workstream.
---

## Closure (analysis-only — no compiler change)

Same root cause as the broader closure-capture-in-loop family.
The Vec<closure> shape compounds the issue because:

- Each closure stored in the Vec carries its own captured-env.
- Indexing `vec_get(closures, i)` produces an i64-cast pointer
  to the closure record.
- Calling that record inside a loop body asks the closure-
  capture-flow analysis to handle BOTH the loop-body re-write
  case AND the indirect-call-via-pointer case.

The lower path doesn't yet handle the combined case.

## Adopter migration

Same fn-args-instead-of-captures pattern from the broader
finding. For Vec<closure> specifically:

```nucleor
// Pre-fix shape:
let closures: Vec<|i64| -> i64> = vec![|x| x + 1, |x| x * 2];
let mut i: i64 = 0;
while i < 2 {
    print_int(closures[i](10));    // ← may produce wrong output
    i = i + 1;
};

// Workaround (fn pointers via ID dispatch):
fn fn_a(x: i64) -> i64 { return x + 1; }
fn fn_b(x: i64) -> i64 { return x * 2; }
fn dispatch(id: i64, x: i64) -> i64 {
    if id == 0 { return fn_a(x); };
    return fn_b(x);
}
let mut i: i64 = 0;
while i < 2 {
    print_int(dispatch(i, 10));
    i = i + 1;
};
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
