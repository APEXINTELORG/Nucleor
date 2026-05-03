---
title: Closure body can't call a sibling closure binding — `let a = |x| ...; let b = |x| a(x) + 1;` fails with TYP-005 "undefined function 'a'"
severity: silent-miscompute (closure cross-reference gap)
probe_file: probes/closures/closure_call_sibling.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-005 "undefined function 'a'" inside closure b's body
diagnostic_expected: closure b can call closure a as if both were fn-decls in the enclosing scope
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — bundled with the closure-capture-flow family. Same v1 borrow-checker workstream as the Vec<closure>, in-loop-body, and move-semantics findings. Today closures only accept fn-decl callees, not other closure bindings.
---

## Closure (analysis-only — no compiler change)

The closure body type-check at line ~17590 (closure body env)
doesn't yet propagate the enclosing scope's let-bindings into
the closure's typing env, so any reference to a sibling closure
binding from inside another closure's body fails the kind-7
(call) check with TYP-005.

### Workaround

```nucleor
// Pre-fix (TYP-005):
let a: |i64| -> i64 = |x: i64| x + 1;
let b: |i64| -> i64 = |x: i64| a(x) + 1;     // ← TYP-005

// v0.6 workaround — lift to fn:
fn add_one(x: i64) -> i64 { return x + 1; }
let b: |i64| -> i64 = |x: i64| add_one(x) + 1;     // works
```

## Forward-roadmap

The closure body's env lookup needs to walk up the enclosing
scope and pick up other closure bindings. Same workstream as
the broader closure-capture-flow rework.

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
