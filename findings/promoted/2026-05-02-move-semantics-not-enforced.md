---
title: Move semantics not enforced — `let v2 = v;` then `let n = vec_len(v);` builds clean and `v2`/`v` both reference the same Vec backing store. No use-after-move diagnostic.
severity: silent-miscompute (memory-safety class — borrow-checker gap)
probe_file: probes/ownership/move_semantics_audit.nr (probe-branch)
diagnostic_actual: pre-fix — no diag, both `v` and `v2` work, double-free risk on explicit cleanup
diagnostic_expected: borrow-checker reports use-after-move on `v` after `let v2 = v;` (Rust convention)
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — borrow-checker enforcement is the v1 workstream that also enables auto-Drop and full RAII. Today adopters keep ownership in mental model; the i64-everywhere ABI means `let v2 = v` aliases the same heap pointer (no copy semantic), so dual-cleanup is the actual hazard surface to avoid.
---

## Closure (analysis-only — no compiler change)

The Nucleor v0.6 type system uses i64-everywhere ABI: every
heap-allocating type (Vec, String, HashMap, Box, Rc, etc.)
flows as a pointer cast to i64. `let v2 = v` copies the i64
pointer — both bindings reference the same backing store.

The actual hazard:

- ✓ Reading via either name works (same pointer).
- ✗ Calling `vec_free(v)` then `vec_free(v2)` is a double-free
  → Windows STATUS_HEAP_CORRUPTION (rc=-1073740940 / 0xC0000374).
- ✗ Calling `vec_push(v, ...)` after `vec_free(v2)` is use-after-
  free → STATUS_ACCESS_VIOLATION (rc=-1073741819).

Adopters today follow a mental-ownership convention:

```nucleor
let v: Vec<i64> = make_vec();
let v2: Vec<i64> = v;       // mental "move": don't use v anymore
// use v2 only
vec_free(v2);                // single cleanup
```

The convention is simple but error-prone — exactly the
correctness substrate that the v1 borrow-checker is meant to
enforce.

### Sister findings (same workstream)

- `2026-05-01-drop-trait-never-auto-called` (RAII / Drop auto-
  call)
- `2026-04-30-vec-allocation-without-drop-leaks` (scope-exit
  leaks)

All three close together when v1 borrow-checker + scope-flow
pass lands.

## Forward-roadmap

The v1 borrow-checker is the mid-roadmap workstream that closes
this finding family. Until then, the i64-everywhere ABI's
pointer-aliasing-on-assignment is the documented (if leaky)
abstraction.

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
