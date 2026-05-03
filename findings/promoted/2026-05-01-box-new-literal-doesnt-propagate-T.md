---
title: `let b: Box<i64> = Box::new(5);` — type inference for `Box::new(<literal>)` doesn't propagate T from let-binding annotation. `5_i64` suffix also fails. Only explicit `as i64` cast works.
severity: silent-miscompute (type inference gap; sister to v0.5.13 generic-T propagation)
probe_file: probes/generics/box_new_literal.nr (probe-branch)
diagnostic_actual: `error[TYP-008]: type mismatch for binding 'b'`
diagnostic_expected: build succeeds (T = i64 inferred from `Box<i64>` annotation)
discovered_against: main v0.5.17 (probe 789cb62)
commit: probe 789cb62 + main 736d88a
status: DOC-ONLY — workaround `Box::new(5 as i64)` works cleanly. Infer-from-let-annotation requires the type-checker to push the binding's expected type into the call's generic argument resolution; that's a v1 generic-inference pass, deferred for the borrow-checker workstream.
---

## Closure (analysis-only — no compiler change)

The diagnostic is correct in name (TYP-008 type mismatch) but
unhelpful in scope: it points at the binding without naming the
gap (Box::new returns Box<inferred-from-arg-default-type>, which
defaults to i32 for unsuffixed integer literals).

Workarounds (pick the one that fits adopter style):

```nucleor
let b: Box<i64> = Box::new(5 as i64);    // explicit cast — recommended
let b: Box<i64> = Box::new(5i64);         // suffix DOES work today (inline form)
let n: i64 = 5; let b: Box<i64> = Box::new(n);   // bind-then-box
```

(The probe noted `5_i64` underscore-form suffix fails; the
no-underscore `5i64` works — that's an existing probe-side
sub-finding, not a separate gap.)

### Sister findings

- `2026-04-30-i32-binop-no-narrow-in-expression-context` — same
  family of "literal default to i32, narrowing happens at let-
  binding only" gaps. Both close together when the v1 generic-
  inference / type-context-propagation pass lands.
- `2026-05-01-generic-T-trait-bound-method-dispatch` — generic-T
  propagation on trait-bound methods. Same workstream.

## Forward-roadmap

The fix requires bidirectional type inference: the let-binding
annotation `Box<i64>` should flow into the call site as an
expected-T constraint, narrowing the literal to i64 before the
call site checks for type mismatch. That's a non-trivial
type-checker extension; deferred to the v1 generic-inference
pass.

## Promoted

- No code change in v0.6.50 batch.
- Workaround documented; sister findings cross-referenced.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
