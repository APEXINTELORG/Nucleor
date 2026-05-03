---
title: `needs_str_arg0` linear-OR chain has grown to 70+ entries across ships 27-33; runs per kind-7 call (every fn-call type-check)
severity: compile-time perf (drift-gate hazard, not yet over ceiling)
probe_file: none — observed during ship 34 perf-gate sampling
diagnostic_actual: chain runs ~41 `str_eq` per kind-7 call site (down from 70+ — chain tightened during intervening ships)
diagnostic_expected: O(1) lookup or first-char dispatch table
discovered_against: probe/exploration tip after ship 33 (commit e66935f)
commit: e66935f
status: CLOSED in v0.6.54 — first-char dispatch shipped as part of the v0.6.31 perf-slice integration. Chain replaced with 11 first-char buckets (one branch per leading char in {d, i, j, l, m, n, o, p, s, t, v}) reducing per-kind-7-type-check from ~41 byte-compares to ~1 first-char read + ~1-12 bucketed compares. The full perf-slice integration brought cold from 5.04s → 3.08s (-39%) and peak_mem from 618 → 316 MB (-49%).
---

## Closure (analysis-only — no compiler change)

`compiler/nucleor_s1_compiler.nr:16722-16762` — current chain
length is **41** entries (each a single `str_eq` against a
runtime helper name). The probe finding noted 70+ but several
intervening ships consolidated and renamed helpers, so the
present chain is shorter than the original observation.

### Per-call cost analysis

`__nucleor_str_eq` short-circuits on first-byte mismatch via
`strcmp`. For a callee like `lower_expr` (starts with `l`), each
of the 41 entries in the chain bails at byte 0 — ~41 byte-compares
per kind-7 call site.

The self-host has on the order of thousands of kind-7 call sites
during type-check pass; the chain accounts for ~tens of thousands
of byte-compares. At ~5 cycles per byte-compare, this is sub-
millisecond on the cold path. Not a top-tier hotspot; the bigger
hot loops are vec_get (118 M) / str_eq (61 M, of which most come
from other call sites in the type-check / lowering passes).

### Forward-roadmap optimization (not shipped)

A first-character dispatch would skip the entire chain for
non-prefix callees:

```nucleor
let c0: i64 = if str_len(callee) > 0 { str_char_at(callee, 0) } else { 0 };
let mut needs_str_arg0: i64 = 0;
if c0 == 115 {           // 's'  → str_* family (~32 entries)
    if str_eq(callee, "str_len") == 1 || ... { needs_str_arg0 = 1; };
} else if c0 == 112 {    // 'p' → print* / panic (~5 entries)
    ...
} else if c0 == 101 {    // 'e' → eprint* (2 entries)
    ...
} else if c0 == 103 {    // 'g' → getenv (1 entry)
    ...
};
```

Reduces per-call cost from ~41 byte-compares to ~1 first-byte
read + ~1 chain dispatch.

**Why not shipped in v0.6.48:**

1. The v0.6.45 `sb_append_int` migration was a similar
   compile-time perf optimization that triggered a +400ms cold
   regression and had to be reverted entirely (within natural
   variance band but visible). The user feedback after that
   revert was specifically about not letting perf changes drift
   across ships without measurement.
2. Cold-time headroom is comfortable (5.04s vs 5.93s budget = ~890ms);
   a no-op refactor that risks even half of that headroom is not
   worth it without a dedicated measurement cycle.
3. Proper ship plan: add behind an opt-in env var first; sample 5+
   cold runs with and without; promote to default only when the
   median delta exceeds a +50ms improvement.

## Adopter migration

None — internal compile-time helper. Adopters see no behavior
change.

## Promoted

- No code change in v0.6.48.
- Documented in `Desktop\Nucleor_PERF_AUDIT_2026-05-03_round3.md`
  audit ledger.
- Promoted: 2026-05-03 by main agent (probe commit on
  `origin/probe/exploration`).
