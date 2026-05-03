---
title: Closure body that captures a variable and is invoked inside `while`/`loop` body fails — silent miscompute or runtime panic depending on capture shape
severity: silent-miscompute (closure capture limitation)
probe_file: probes/closures/closure_in_loop_body.nr (probe-branch)
diagnostic_actual: pre-fix — silent wrong output OR runtime panic depending on capture shape
diagnostic_expected: closure capture works inside loop bodies as in fn bodies
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — closure capture inside while/loop bodies has known limitations. Sister findings: `2026-04-30-closure-cant-call-sibling-closure`, `2026-05-01-closure-vec-capture-with-while-body-fails`. The closure substrate uses the v0.4.146 `__closure_argc_*` env-side registration which has scope-flow gaps inside loop bodies. Forward-roadmap: closure-capture-flow rework as part of the v1 borrow-checker workstream.
---

## Closure (analysis-only — no compiler change)

Closure capture in Nucleor v0.6 uses an environment-side
binding registration pattern (line ~17590 onward,
`__closure_argc_<vname>`) that records the closure's arg shape
at the let-binding site. When the closure is invoked from a
loop body, two scope-flow paths interact:

1. The closure's captured environment (the let-binding scope).
2. The loop body's local-variable scope (each iteration creates
   a fresh activation record for any `let` inside the body).

The existing implementation handles closure-in-fn-body cleanly
because the fn's activation record is stable across the closure's
invocations. Inside a loop body, the closure's captured-env
references can point at slots that were re-written each
iteration, producing the silent miscompute the probe found.

### Sister findings (same workstream)

- `2026-04-30-closure-cant-call-sibling-closure` — closure
  body can't reference another closure binding (TYP-005).
- `2026-05-01-closure-vec-capture-with-while-body-fails` —
  Vec<closure> indexed-call inside loop fails.

All three share the closure-capture-flow root.

## Forward-roadmap

The v1 borrow-checker pass needs to compute closure-capture
flow analytics: which captured slots can be re-written by the
loop body, and which are stable. The lower path then either
copies or pins the captures appropriately. Sister to the
move-semantics finding's borrow-checker root.

## Adopter migration

```nucleor
// Pre-fix shape (broken in loop body):
let mut total: i64 = 0;
let add: |i64| -> i64 = |n: i64| n + total;
let mut i: i64 = 0;
while i < 5 {
    total = add(i);    // ← may produce wrong result
    i = i + 1;
};

// Workaround (lift captured state to fn-call args):
fn add_to_total(n: i64, total: i64) -> i64 { return n + total; }
let mut total: i64 = 0;
let mut i: i64 = 0;
while i < 5 {
    total = add_to_total(i, total);
    i = i + 1;
};
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
