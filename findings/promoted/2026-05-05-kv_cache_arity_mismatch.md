# Finding — kv_cache rod / runtime arg-count mismatch

**Date:** 2026-05-05
**Surfaced by:** main agent during v0.8.212 zero-coverage rod sweep
**Status:** documented; smoke deferred until fixed.

## Symptom

`stdlib/rods/kv_cache.nr` declares 4-arg getters:

```nucleor
extern fn nuc_kv_cache_get_k(ch: i64, layer: i64, head: i64, pos: i64) -> i64;
extern fn nuc_kv_cache_get_v(ch: i64, layer: i64, head: i64, pos: i64) -> i64;
```

`stdlib/runtime/kv_cache_rt.c` defines them with 5 args:

```c
long long nuc_kv_cache_get_k(long long ch, long long layer, long long head,
                              long long start_pos, long long end_pos) { ... }
long long nuc_kv_cache_get_v(long long ch, long long layer, long long head,
                              long long start_pos, long long end_pos) { ... }
```

The C runtime treats `pos` as `start_pos` and reads garbage from
the un-pushed stack slot for `end_pos`. The output Vec is then
sized as `(end_pos - start_pos) * head_dim` with random values.

Same shape as the v0.8.45 ML-1 attention_flash bug fixed for
attention2 (rod 6-arg → C 7-arg with seq_q/seq_k split).

## Root cause hypothesis

Refactor of the gather-range C surface (start/end pair) was
not echoed in the rod extern signatures. The rod still presents
a single-position read API.

## Proposed fix (one of)

A. **Update rod sig to match C** — 5 args, return Vec of (end-start) tokens.
B. **Add C wrapper** that takes a single `pos` and calls the
   range form with `(pos, pos+1)`.

(B) is non-breaking; (A) breaks any caller already using
`kv_get_k(ch, l, h, pos)`. Since this is a launch-window OSS
distro, propose (B) — keep the rod's 4-arg semantics, add a
small C shim.

## Test fixture deferred

Drafted `tests/features/kv_cache_smoke.nr` was held back; would
have given false confidence (rod compiles + runs, but reads are
garbage).

## Cross-references

- v0.8.45 ML-1 fix (analogous, attention2 rod) —
  `compiler/nucleor_s1_compiler.nr` and
  `stdlib/rods/attention2.nr` carry the precedent comment.
- RFC NUC-FEEDBACK-X (extern-sig drift hardening) — proposed
  audit-pass token gate to flag rod-vs-runtime arg-count drift
  at compile time.
