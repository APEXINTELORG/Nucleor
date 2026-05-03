---
title: Vec/String/HashMap allocations leak without explicit `vec_free` — no automatic Drop on scope exit or rebinding
severity: silent-miscompute (memory-leak class — matches user mandate "always look for memory blow ups")
probe_file: probes/perf/vec_alloc_loop_leak.nr (probe-branch)
diagnostic_actual: pre-fix — no diagnostic, peak grows linearly with allocation count
diagnostic_expected: either (a) automatic Drop on scope exit / rebinding, OR (b) compile-time warning at heap-allocating binding scope exit / rebind
discovered_against: v0.4.204 + 16-ship probe-prep stack on commit 43367e5
commit: 43367e5
status: DOC-ONLY — sister to `2026-05-01-drop-trait-never-auto-called`. Drop / RAII auto-call is the v1+ feature; today adopters explicitly free via `vec_free` / `hashmap_free` / `string_free`. Hot-loop allocators are flagged via MEM-001 (rebind class) — extending MEM-001 to scope-exit-leak is forward-roadmap for the same workstream.
---

## Closure (analysis-only — no compiler change)

This finding is the loop-scope-binding cousin of the **Drop trait
not auto-called** finding (`2026-05-01-drop-trait-never-auto-called`).
Both surface the same root: Nucleor v0.6 does not yet auto-emit
free-on-scope-exit calls. Adopters explicitly call `vec_free(v)`,
`hashmap_free(h)`, `string_free(s)` before the binding goes out
of scope.

The probe matrix demonstrates three shapes:

1. Loop-scope `let v: Vec<i64> = Vec::new();` — leaks each
   iteration.
2. Rebind in loop `s = str_concat(s, "x")` — leaks the previous
   string each iteration. (Sister finding
   `2026-04-30-str-concat-loop-rebind-leak`.)
3. Function-return Vec/HashMap captured as let-binding — leaks
   when binding exits scope.

All three are the same root: Drop / RAII auto-call.

### Why doc-only this cycle

- **Cross-cutting**: auto-Drop touches the lower path for every
  allocating type. v0.6.x has tactical MEM-001 catches for
  specific patterns (rebind, reassignment) but not generalized
  scope-exit detection. Generalizing it requires a borrow-checker
  scope-flow pass.
- **Adopter migration is mechanical**: explicit `vec_free` /
  similar before scope exit. Existing fixtures (and the compiler
  self-host) follow this pattern.
- **Bundled with the Drop finding**: v1 RAII work is the natural
  ship that closes both this and the Drop-trait finding together.

## Adopter migration

```nucleor
// Pre-fix (leak):
fn main() -> i32 {
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < 10000000 {
        let v: Vec<i64> = Vec::new();    // leaked each iter
        total = total + vec_len(v);
        i = i + 1;
    };
    return total as i32;
}

// v0.6 idiom (explicit free):
fn main() -> i32 {
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < 10000000 {
        let v: Vec<i64> = Vec::new();
        total = total + vec_len(v);
        vec_free(v);                      // explicit close
        i = i + 1;
    };
    return total as i32;
}

// v0.6 alternative (lift-out-of-loop):
fn main() -> i32 {
    let mut total: i64 = 0;
    let mut v: Vec<i64> = Vec::new();     // one alloc, reused
    let mut i: i64 = 0;
    while i < 10000000 {
        vec_clear(v);                      // reset state
        total = total + vec_len(v);
        i = i + 1;
    };
    vec_free(v);
    return total as i32;
}
```

The lift-out-of-loop pattern is what the compiler self-host
uses (e.g. `sb` builders in `emit_module_ext`).

## Forward-roadmap

When the v1 borrow-checker / RAII pass lands, this finding closes
together with the Drop-trait finding. The MEM-001 family will
then generalize from the current rebind-class catches to full
scope-exit-leak detection.

## Promoted

- No code change in v0.6.50 batch.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
