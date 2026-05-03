---
title: `assert_eq!(a, b)` for `Vec<T>`, struct, and `HashMap` types compares the i64-cast pointer values, not the structural content. `assert_eq!(vec_a, vec_b)` succeeds only if both bind to the exact same heap pointer — not when both vectors contain the same elements.
severity: silent-miscompute (assert semantics — pointer-compare instead of structural-compare)
probe_file: probes/assert/assert_eq_vec_struct_hashmap.nr (probe-branch)
diagnostic_actual: pre-fix — pointer compare; `[1,2,3]` vs `[1,2,3]` (different allocations) fails
diagnostic_expected: structural compare matching Rust convention (PartialEq on element-wise basis)
discovered_against: main v0.6.20 (probe rebased)
commit: probe (post-rebase) + main 0ac46486
status: DOC-ONLY — sister to the v0.6.x assert_eq_str fix (which added structural string compare). Extending to Vec/struct/HashMap requires a per-type assert dispatch and structural-compare helpers for each container shape. Forward-roadmap.
---

## Closure (analysis-only — no compiler change)

The Nucleor v0.6 `assert_eq!` macro emits a runtime
`__nucleor_assert_eq` call that compares the two arguments as
i64 values. For str args, v0.6.x added a special-case to
dispatch to `__nucleor_str_eq` (structural compare). For Vec /
struct / HashMap args, no such special-case exists; the i64
compare is a pointer compare.

Adopters get:

```nucleor
let a: Vec<i64> = vec![1, 2, 3];
let b: Vec<i64> = vec![1, 2, 3];
assert_eq!(a, b);    // ← FAILS — different heap allocations, pointer compare returns false
```

This violates the canonical Rust assert_eq semantics (which
calls PartialEq on element-wise basis).

### Forward-roadmap

The fix needs:

1. Per-type dispatch in the assert_eq macro (already exists for
   str; extend for Vec, struct, HashMap).
2. Structural-compare helpers for each container:
   - `__nucleor_vec_eq(a, b)` — element-wise compare.
   - `__nucleor_hashmap_eq(a, b)` — key-set + value-by-key
     compare.
   - For structs: derived field-wise compare (auto-emit at the
     struct decl based on field types).

Bundled with the v1 derive(PartialEq) workstream.

## Adopter migration

```nucleor
// Pre-fix shape (FAILS for separate heap allocations):
let a: Vec<i64> = vec![1, 2, 3];
let b: Vec<i64> = vec![1, 2, 3];
assert_eq!(a, b);        // ← fails

// v0.6 workaround — explicit element-wise:
fn vec_eq(a: Vec<i64>, b: Vec<i64>) -> bool {
    if vec_len(a) != vec_len(b) { return false; };
    let mut i: i64 = 0;
    while i < vec_len(a) {
        if vec_get(a, i) != vec_get(b, i) { return false; };
        i = i + 1;
    };
    return true;
}

let a: Vec<i64> = vec![1, 2, 3];
let b: Vec<i64> = vec![1, 2, 3];
assert!(vec_eq(a, b));   // ← passes
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
