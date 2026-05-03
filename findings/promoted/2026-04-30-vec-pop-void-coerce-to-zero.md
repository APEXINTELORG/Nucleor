---
title: `let x = vec_pop(v)` silently binds 0 — vec_pop is `void` at runtime, but kind-7 type_expr returns the Vec's element type (treated as value-returning Rust-like helper), so TYP-021 didn't fire.
severity: silent-miscompute
probe_file: probes/_sweep/p2_vec_pop_empty.nr (probe-branch)
diagnostic_actual: pre-fix — silent; binds 0 always (no diagnostic).
diagnostic_expected: TYP-021 hard error at let-stmt time, naming vec_pop as a void helper.
discovered_against: probe/exploration tip after ship 41 (commit 6927234)
commit: 6927234 + main 5b49b0fb
status: CLOSED in v0.6.42 via let-binding override at TYP-021 site — when RHS is a direct kind-7 call to vec_pop, override init_t to "void".
---

## Closure (main agent v0.6.42)

`compiler/nucleor_s1_compiler.nr` let-binding TYP-021 site (line
~17277) — when the RHS is a direct kind-7 call AND the callee is
`vec_pop`, override `init_t` to `"void"` so the existing TYP-021
check fires. type_expr for vec_pop continues to return the Vec's
element type via the vec-read-call path (kept for backward-compat
with annotated forms `let x: i64 = vec_pop(v);` which would now
fire TYP-008 with that path — but actually currently fires
nothing because element_t fits as i64); the bare-let form gets
the override.

## Adopter migration

```nucleor
// Pre-v0.6.42: silent 0-bind, indistinguishable from popped 0
let x = vec_pop(v);

// v0.6.42: TYP-021 halts
//
// Workaround:
let last: i64 = vec_last(&v);   // peek
vec_pop(v);                     // remove (void, no binding)
print_int(last as i32);
```

## Why a let-binding override, not a global type_expr fix

Removing vec_pop from the vec-read-call set in type_expr would
also cause `let x: i64 = vec_pop(v);` (annotated form) to start
firing TYP-008 (type mismatch — void vs i64). That's the more
correct halt, but it ripples through every existing `vec_pop`
call in the tools-suite source. The let-binding override targets
the exact silent-miscompute case (bare `let x = vec_pop(v)`)
without affecting the wider compatibility surface.

## Forward-roadmap

A future ship can:
- Promote vec_pop to a typed Option<T>-returning helper (matches
  Rust's `vec.pop()` semantics) — substantial.
- Or: remove vec_pop from the vec-read-call set entirely and
  audit the tools-suite to drop any `let x: i64 = vec_pop(v)`
  patterns. Smaller, but breaking.

## Promoted

- Fixture: `tests/err/err_typ_021_vec_pop_void_bind.nr`.
- Fix shipped: v0.6.42 (let-binding override only).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
