---
title: `vec_insert_at(&mut v, idx, val)` does NOT bounds-check `idx` against `len`. Out-of-bounds idx silently appends val at the end (clamps to len). Negative idx silently prepends (clamps to 0). Asymmetric with vec_swap / vec_get / vec_remove_at which all PANIC on OOB.
severity: silent-miscompute (asymmetric Vec-helper OOB coverage)
probe_file: probes/vec/vec_insert_at_no_oob_check.nr (probe-branch)
diagnostic_actual: pre-fix — vec_insert_at(&v, 99, 42) on len=1 vec silently appends; vec_insert_at(&v, -1, 42) silently prepends.
diagnostic_expected: PANIC matching the existing diag style of vec_swap / vec_get / vec_remove_at, with NUCLEOR_VEC_OOB_LENIENT=1 escape hatch.
discovered_against: main v0.6.13 (probe rebased)
commit: probe (post-rebase) + main ec91b08d
status: CLOSED in v0.6.44 — vec_insert_at PANICs on i < 0 || i > v->len; insert-at-end (i == len) still permitted; lenient mode preserves legacy clamp behavior.
---

## Closure (main agent v0.6.44)

`stdlib/runtime/nucleor_llvm_rt.c` `__nucleor_vec_insert_at` —
pre-fix unconditionally clamped `i` to `[0, len]`. Post-fix:
PANIC unless `0 <= i <= len` (insert-at-end is permitted, since
that's the canonical "append via insert" case). Diag wording
matches v0.6.30's Rust-canonical OOB phrasing. The
`NUCLEOR_VEC_OOB_LENIENT=1` env var preserves the legacy clamp
path for adopters opting out.

## Adopter migration

```nucleor
let mut v: Vec<i64> = Vec::new();
vec_push(&mut v, 10);

// Pre-v0.6.44: silent clamp to len, appends at end
vec_insert_at(&mut v, 99, 42);

// v0.6.44: PANIC at the call site
// Workaround: explicit append
vec_push(&mut v, 42);

// Insert at len (= append) still works:
vec_insert_at(&mut v, vec_len(&v), 42);   // OK
```

## Promoted

- Smoke validation: OOB insert PANICs cleanly; in-range inserts
  (front / middle / end) all work correctly.
- Fix shipped: v0.6.44.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
