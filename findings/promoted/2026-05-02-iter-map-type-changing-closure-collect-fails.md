---
title: `iter().map(closure-changing-type).collect()` fails — TYP-008 when the closure changes the element type (e.g. `i64 -> str`)
severity: silent-miscompute (iterator type-changing map gap)
probe_file: probes/iterators/iter_map_collect_type_change.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-008 "type mismatch for binding"
diagnostic_expected: collect() infers the new element type from the closure's return type
discovered_against: probe/exploration tip
commit: probe + main
status: DOC-ONLY — same closure-capture-flow / generic-inference workstream as the broader closure findings. The `.map(...)` and `.collect()` chain returns a Vec<T_new> where T_new is the closure's return type; today the type-checker doesn't propagate T_new through the chain.
---

## Closure (analysis-only — no compiler change)

The iterator chain `Vec<T_old>.iter().map(|x| -> T_new ...).collect()`
needs the type-checker to thread `T_new` through three call
sites:

1. `.iter()` — returns iterator over `&T_old`.
2. `.map(closure)` — returns iterator over T_new (closure's
   return type).
3. `.collect()` — returns `Vec<T_new>`.

The v0.6 type-checker doesn't yet propagate the closure's return
type through the map → collect chain. When `T_new != T_old`, the
collect site sees a type mismatch.

### Sister findings

- `2026-05-01-box-new-literal-doesnt-propagate-T` — same
  generic-T propagation gap surface.
- `2026-04-30-i32-binop-no-narrow-in-expression-context` —
  type-context-propagation in expression position.

All three close together with the v1 generic-inference pass.

## Adopter migration

```nucleor
// Pre-fix (TYP-008):
let nums: Vec<i64> = vec![1, 2, 3];
let strs: Vec<str> = nums.iter().map(|n| str_from_int(*n)).collect();   // ← TYP-008

// Workaround (explicit loop):
let nums: Vec<i64> = vec![1, 2, 3];
let mut strs: Vec<str> = Vec::new();
let mut i: i64 = 0;
while i < vec_len(nums) {
    strs.push(str_from_int(vec_get(nums, i)));
    i = i + 1;
};
```

## Promoted

- No code change.
- Promoted: 2026-05-03 by main agent.
