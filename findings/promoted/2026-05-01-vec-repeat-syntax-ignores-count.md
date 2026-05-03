---
title: `vec![X; N]` (Rust repeat-syntax) ignores `N`. Always produces a 1-element vec containing only `X`. Adopters writing canonical `vec![0; capacity]` to pre-allocate a buffer get a 1-element vector regardless of the requested count. Indexing past 0 PANICs OOB.
severity: silent-miscompute (canonical Rust idiom — affects every translated buffer pre-alloc)
probe_file: probes/vec/vec_repeat_count_ignored.nr (probe-branch)
diagnostic_actual: pre-fix — build + run succeed; `vec![7; 5]` produces a length-1 vec; `vec_get(&v, 1)` PANICs OOB.
diagnostic_expected: produce a length-N vec where every element equals X; `vec_get(&v, k)` for `0 <= k < N` returns X.
discovered_against: main v0.5.28 (probe rebased)
commit: probe (post-rebase) + main ff0054f1
status: CLOSED in v0.6.41 via top-level `;` detection in the `vec!` macro expander, emitting a while-loop that pushes X N times.
---

## Closure (main agent v0.6.41)

`compiler/nucleor_s1_compiler.nr` `vec!` macro expansion (line
~28103) — added a top-level `;` scan BEFORE the comma-split
path. If a top-level `;` is found (boundary-aware: skips inside
quoted strings, `()`, `[]`, `{}`), splits at that position and
emits a while-loop:

```nucleor
{ let mut __nuc_vec: Vec<i64> = Vec::new();
  let mut __nuc_repeat_i: i64 = 0;
  let __nuc_repeat_n: i64 = (count) as i64;
  while __nuc_repeat_i < __nuc_repeat_n {
      __nuc_vec.push(value);
      __nuc_repeat_i = __nuc_repeat_i + 1;
  };
  __nuc_vec }
```

The original comma-split path is preserved for `vec![1, 2, 3]`,
and the empty-Vec path for `vec![]` is unchanged.

## Adopter migration

```nucleor
// Pre-v0.6.41: silent length-1
let v: Vec<i64> = vec![7; 5];   // length=1, vec_get(&v, 1) PANICs OOB

// v0.6.41: canonical Rust semantics
let v: Vec<i64> = vec![7; 5];   // length=5, every element 7
let v2: Vec<i64> = vec![0; 100]; // length=100, all zeros (typical buffer pre-alloc)
```

Comma-form unchanged: `vec![1, 2, 3]` still produces a 3-element
Vec. Empty `vec![]` still produces an empty Vec.

## Forward-roadmap (non-i64 element types)

The current `vec!` expander always emits `Vec<i64>` as the
element type — works for the common case but adopters pushing
non-i64 elements (Vec<f64>, Vec<str>, Vec<struct>) would need
an inferred element type. The repeat form has the same
limitation: the value expression is treated as i64. Future
ship can extend type inference into the macro expander to
emit `Vec<T>` based on the value expression's type.

## Promoted

- Fixture: `tests/features/vec_macro_repeat.nr` (positive —
  exercises repeat form, comma form, and empty form).
- Fix shipped: v0.6.41.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
