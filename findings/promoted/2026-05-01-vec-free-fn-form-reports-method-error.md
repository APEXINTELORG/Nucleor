---
title: Free-fn form `vec_sort(v)` / `vec_clear(v)` fails with TYP-005 message about "no method `.sort()` / `.clear()`" — diagnostic mentions method dispatch even though source uses free-fn syntax.
severity: wrong-error (diagnostic quality / misleading)
probe_file: probes/vec/vec_free_fn_form_misreport.nr (probe-branch)
diagnostic_actual: pre-fix — TYP-005 mentioning the method form even though the source has no method call.
diagnostic_expected: TYP-005 naming the fn-form misuse, suggesting the method form.
discovered_against: main v0.5.17 (probe 789cb62)
commit: probe 789cb62 + main 32d68126
status: CLOSED in v0.6.40 — same fix as sister finding 2026-05-01-vec-contains-symbol-not-emitted. The fn-form-vs-method-form hint applies to every supported Vec method (contains, push, pop, len, get, set, first, last, is_empty, insert_at, remove_at, iter, map, filter, fold, each, sum, min, max, index_of, reverse, sort, clone, clear).
---

## Closure (covered by v0.6.40 sister fix)

`compiler/nucleor_s1_compiler.nr` undefined-fn diag (line ~28475)
v0.6.40 close — when the failing symbol is `vec_<method>` AND
`<method>` is in the supported Vec method families list, emit
the fn-form-vs-method-form hint instead of the "no method" diag.

`vec_clear`, `vec_sort` are both in the supported list, so the
new hint fires automatically for them. Same fix shape as
`vec_contains`.

## Smoke validation

```
$ nucleor build vec_clear_freefn.nr 2>&1
error[TYP-005]: `vec_clear(...)` is not a top-level fn — use the
method form `vec.clear(&value)` instead. The method-dispatch
path resolves to the correct type-specific runtime helper …
                Pre-v0.6.40 the diag said `no method .clear()`,
which was misleading — the method exists, only the fn-form does
not.
```

## Adopter migration

```nucleor
let mut v: Vec<i64> = vec![1, 2, 3];

// Pre-v0.6.40: misleading TYP-005 "no method `.clear()`"
vec_clear(v);

// v0.6.40: fn-form-vs-method-form hint
// Workaround: use method form (works since v0.4.x):
v.clear();
```

## Promoted

- Smoke validation: pre-fix old "no method" diag; v0.6.40 fn-form
  vs method-form hint.
- Fix shipped: v0.6.40 (same fix as sister `vec_contains`).
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
