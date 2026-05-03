---
title: `#[isr]` inherits `#[no_alloc]` + `#[no_panic]` ON THE FN BODY but the checks do NOT propagate through callees. An ISR can transitively allocate (Vec::new + vec_push) or panic by routing through a regular helper fn, defeating the safety promise of the inheritance.
severity: silent-miscompute / safety-hole (RFC-0008 ISR substrate — body-local checks only)
probe_file: probes/isr/isr_inheritance_not_transitive.nr (probe-branch)
diagnostic_actual: pre-fix — direct body usage rejects (RT-001/RT-002), helper-routed usage compiles clean
diagnostic_expected: RT-001/RT-002 propagate through call edges from `#[isr]` fns
discovered_against: main v0.6.10 (probe rebased)
commit: probe (post-rebase) + main cc8311f
status: DOC-ONLY — call-graph propagation of the no_alloc / no_panic substrate is the v1 RFC-0008 phase 2 workstream. The substrate today (RFC-0008 phase 1) checks fn-body-local — direct alloc/panic in the body of `#[isr]` fn or `#[no_alloc]/#[no_panic]` fn. Transitive enforcement requires walking the call graph, marking reached fns, and rejecting any reached fn that body-locally allocates/panics. Forward-roadmap.
---

## Closure (analysis-only — no compiler change)

The RFC-0008 substrate today operates at fn-body granularity:

- `#[no_alloc] fn f() { ... }` rejects if `f`'s body contains
  Vec::new, vec_push, str_concat, sb_new, etc.
- `#[no_panic] fn f() { ... }` rejects if `f`'s body contains
  panic!, assert!, etc.
- `#[isr]` inherits both: `#[isr] fn handle() { ... }` rejects
  body-local alloc and panic.

The gap: when `f` calls `helper_that_allocates()`, the check
doesn't follow the call edge. `helper_that_allocates` may
allocate freely, and `f`'s `#[no_alloc]` annotation no longer
holds transitively.

### Why deferred

Transitive enforcement needs:

1. Per-fn analysis: classify each fn as alloc-y / panic-y based
   on body-local content.
2. Call graph walk from each `#[no_alloc]` / `#[no_panic]` /
   `#[isr]` root.
3. Reject if any reached fn is alloc-y / panic-y.
4. Handle indirect call (fn pointer, closure, dynamic dispatch)
   conservatively (assume worst case).

Step 4 is where it gets thorny — fn pointers and closures
escape static call-graph analysis, requiring either type-system
annotations on fn-pointer types or runtime checks (defeating the
zero-cost goal). Bundled with the RFC-0008 phase 2 workstream.

## Adopter migration

```nucleor
// Pre-fix (silent safety hole):
fn helper_that_allocates() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(&mut v, 1);
    return vec_len(v);
}

#[isr]
fn handle() {
    let n: i64 = helper_that_allocates();    // ← compiles clean today
    // ISR has now allocated through the helper, defeating the safety promise.
}

// v0.6 workaround — discipline:
// Manually annotate every helper called from #[isr] fns with #[no_alloc]
// / #[no_panic]; the body-local check on each helper enforces the
// transitive promise.

#[no_alloc]
#[no_panic]
fn helper_safe() -> i64 {
    return 42;    // body-local clean
}

#[isr]
fn handle() {
    let n: i64 = helper_safe();    // ← provably no alloc, no panic
}
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
