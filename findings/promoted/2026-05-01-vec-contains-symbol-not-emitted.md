---
title: **CORRECTION 2026-05-02 (10th tick):** Method form `v.contains(x)` WORKS for all listed methods. Function form `vec_contains(&v, x)` fails with TYP-005 "no method `.contains()`" — misleading because the method DOES exist. The diagnostic claims the method is missing when actually only the fn-name path is missing.
severity: wrong-error / diagnostic-quality (was framed as missing-symbol; corrected to fn-form-vs-method-form mismatch)
probe_file: probes/vec/contains_symbol_missing.nr (probe-branch)
diagnostic_actual: pre-fix — `error[TYP-005]: receiver type 'Vec<T>' has no method '.contains()'` for fn-form `vec_contains(&v, 2)`. Misleading.
diagnostic_expected: either (a) accept fn-form, OR (b) clear "use method form" hint.
discovered_against: main v0.5.25 (probe rebased)
commit: probe (post-rebase) + main 27bb6340
status: CLOSED in v0.6.40 via path (b) — fn-form `vec_<method>(…)` for any supported method now emits a clear "use method form `vec.<method>(…)` instead" diag, naming the typed runtime helper that the method-dispatch path resolves to.
---

## Closure (main agent v0.6.40)

`compiler/nucleor_s1_compiler.nr` undefined-fn diag (line ~28475)
— if the failing symbol is `vec_<method>` AND `<method>` is in
the supported Vec method families list (contains, push, pop,
len, get, set, first, last, is_empty, insert_at, remove_at,
iter, map, filter, fold, each, sum, min, max, index_of, reverse,
sort, clone, clear), emit a fn-form-vs-method-form hint instead
of the original "no method" diag. Unsupported-method case still
gets the original "no method" diag with the supported-methods
list.

## Adopter migration

```nucleor
let v: Vec<i64> = vec![1, 2, 3];

// Pre-v0.6.40: misleading TYP-005 "no method `.contains()`"
let _ = vec_contains(&v, 2);

// v0.6.40: fn-form-vs-method-form hint
// Workaround: use method form (works since v0.4.x):
let _ = v.contains(&2);   // 1
```

## Why hint, not implement fn-form alias

Vec is generic; `.contains()` dispatches to the type-specific
runtime helper (`vec_contains_i64` for Vec<i64>, etc.) at
compile time. Adding a non-typed `vec_contains` global fn would
need the same dispatch logic — duplicating method-resolution at
the fn-name level. Cleaner to point adopters at the method form
which already has the correct dispatch.

## Promoted

- Smoke validation: pre-fix old "no method" diag; v0.6.40 fn-form
  vs method-form hint.
- Fix shipped: v0.6.40.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
