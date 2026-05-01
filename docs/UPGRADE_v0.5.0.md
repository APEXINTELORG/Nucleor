# Upgrading to v0.5.0 — DRAFT (outline)

> **Status:** Outline placeholder. Fills in when Track L (perf
> baseline + content-addressed cache) lands and the v0.5.0 ship
> is cut. Until then, this file documents the SHAPE of the
> upcoming release notes so adopters know what's coming.

**TL;DR (when finalized):** v0.5.0 is the production-robotics +
RFC-0006 DbC + RFC-0007 atomics + RFC-0014 max-depth + content-
addressed-cache release. Upgrade adopter code by:
1. (DbC adopters) Audit `#[require]` / `#[ensure]` predicates
   against new compile-time checks CONTRACT-006 through -011.
2. (Atomics adopters) AtomicI64 / U64 / I32 / U32 / Bool +
   MemOrder enum are first-class types now.
3. (Concurrency adopters) Lock-free `SpscQueue<T>` and
   `MpscQueue<T>` rods.
4. (Recursion-bounded adopters) `#[max_depth = N]` static check.
5. (Build-perf adopters) Content-addressed compilation cache
   under `target/.nuc_cache_v2/`.

This document covers v0.4.238 → v0.5.0 (the v0.5 substantive
arc). For the v0.4.232 → v0.4.241 strict-arithmetic + diagnostic-
quality work, see `UPGRADE_v0.4.241.md`. For the RFC-0006 DbC
landing, see `UPGRADE_v0.4.254.md`.

## Summary of substantive changes

### RFC-0006 Design by Contract — fully shipped (CONTRACT-001..011)

(Cross-reference `UPGRADE_v0.4.254.md` for the core arc.)

New compile-time diagnostics added beyond the v0.4.254 baseline:

| Code | Title | Ship |
|---|---|---|
| CONTRACT-004 | Trait impl strengthens precondition (Liskov) | v0.4.257 |
| CONTRACT-005 | Trait impl weakens postcondition (Liskov) | v0.4.257 |
| CONTRACT-006 | Heap-aliased `old(...)` reject in `#[ensure]` | v0.4.271 |
| CONTRACT-008 | `result` referenced in `#[ensure]` on void fn | v0.4.272 |
| CONTRACT-009 | Unrecognized `NUCLEOR_DBC_MODE` env value | v0.4.275 |
| CONTRACT-010 | `old(...)` used inside `#[require]` | v0.4.277 |
| CONTRACT-011 | Undefined identifier in contract predicate | v0.4.283 |

CONTRACT-007 (cert profile static-proof) remains reserved;
deferred to v1.1+ alongside Verus-style SMT discharge.

### RFC-0007 Track G — Ordered atomics (v0.4.273)

**(populated when v0.5.0 cuts; pulls from v0.4.273 CHANGELOG entry)**

### RFC-0007 Track H — Lock-free SPSC + MPSC queues (v0.4.274)

**(populated when v0.5.0 cuts; pulls from v0.4.274 CHANGELOG entry)**

### RFC-0007 — AtomicBool ordered ops (v0.4.281)

**(populated when v0.5.0 cuts; pulls from v0.4.281 CHANGELOG entry)**

### RFC-0014 Track I — `#[max_depth = N]` static analysis

**(populated when Track I integrates; pulls from
`docs/milestones/spikes/track_i_max_depth_2026-04-30.md` +
v0.5.0 ship CHANGELOG entry)**

DEPTH-001 through DEPTH-005 wired. Runtime helpers
`max_depth_enter` / `max_depth_exit` (TLS-backed counters)
abort on declared-limit overrun.

### Track L — Perf baseline + content-addressed compilation cache

**(populated when Track L lands; pulls from spike artifact +
SPEC-content-addressed-cache-v0.5.md)**

Cache key: SHA-256 of `(source content || compiler-version ||
build-flags-canonical)`. Storage at `target/.nuc_cache_v2/`.
Hit / miss accounting in build output.

### F64 ergonomic wrapper rods (v0.4.260 → v0.4.269)

9 rods now have `*_f64` ergonomic surface — adopter writes
`vec3_f64(1.0, 2.0, 3.0)` instead of manually wrapping every
arg in `f64_to_bits()`. The bits-ABI fns are preserved
unchanged; the new wrappers are purely additive.

| Rod | New wrappers |
|---|---|
| `units` | 1 (`unit_convert_f64`) |
| `kinematics` | 13 (Vec3 + Quaternion ctors + readers) |
| `linalg` | 8 (matrix entry get/set, scale, norm, det, etc.) |
| `csv_table` | 2 (get_f64 / set_f64) |
| `kdt` | 3 (insert_f64, nearest_f64, knearest_f64) |
| `trajectory` motion profiles | 15 (quintic + trapezoid + scurve) |
| `rrt` | 8 (set_bounds_f64, plan_f64, etc.) |
| `fk_chain` | 11 (DH joint, pos / quat readers) |
| `diff_sim` | 3 (gate_f64, backward_f64) |
| `trajectory` advanced primitives | 12 (DMP, TOPP, Catmull, Bezier) |

### Memory-safety opt-in (v0.4.279)

`str_char_at_strict(s, i)` opt-in variant pays `strlen()` and
panics on OOB. Default `str_char_at` keeps cheap-default
semantics (negative-only check). Mirrors `str_substring_strict`
from v0.3.220.

### Compiler-meltdown halt (v0.4.280, TEMPORARY)

ATOMIC-006 catches the compiler-meltdown when an atomic helper
is called inside a closure body (closure sym-table inheritance
gap). **Real fix needs closure sym-table inheritance — multi-cycle
follow-up; tracked under RFC-0025.**

### Stale doc cleanup (v0.4.270)

`docs/language-reference.md` §1.4 + `docs/language-tour.md`
§numerics: removed stale "staged behind `nuc fix --numeric`"
note about strict-mode arithmetic. Strict-mode is the default
since v0.4.238.

### RFC-0033 + RFC-0034 design drafts published (v0.4.284)

Available in `docs/rfcs/`:

- **RFC-0033** — Effects in function types (`with [...]`).
  Design pinned for v0.5 review; full implementation target
  v0.9.
- **RFC-0034** — Compile-time `[]` vs runtime `()` parameters.
  Design pinned for v0.5 review; full implementation target
  v1.0.

Both are **design-only in v0.5** — no compiler surface yet.

## Migration patterns (placeholder — populate at cut)

### From DbC pre-v0.4.254 manual asserts to RFC-0006 attributes

(Cross-reference `UPGRADE_v0.4.254.md` for examples. v0.5.0's
new CONTRACT-006..011 codes catch additional adopter mistakes
that v0.4.254 didn't.)

### From handle-typed atomic ops to typed AtomicI64

**(populated at v0.5.0 cut)**

### From `Vec` polling concurrency to `SpscQueue<T>` / `MpscQueue<T>`

**(populated at v0.5.0 cut)**

### From manual recursion-bound asserts to `#[max_depth = N]`

**(populated when Track I integrates)**

## Build-mode environment variables (consolidated)

| Variable | Purpose | Default | Codes |
|---|---|---|---|
| `NUCLEOR_DBC_MODE` | RFC-0006 strip-out (`debug` / `safe-release` / `release` / `cert`) | `debug` | CONTRACT-001/002/003 fire only in debug; CONTRACT-009 catches typos |
| `NUCLEOR_INT_STRICT_INTRIN` | RFC-0015 strict integer arithmetic via LLVM overflow intrinsics | `1` (since v0.4.238) | NUM panic on overflow |
| `NUCLEOR_VEC_OOB_LENIENT` | Suppress OOB panics in vec / str helpers | unset (strict) | bypass `str_char_at_strict` etc. |
| `NUCLEOR_AUDIT_NUM024` | Emit NUM-024 cross-width call audit | unset | NUM-024 warnings |

## Reference

- RFC: `docs/rfcs/RFC-0006-design-by-contract.md` + RFC-0007 +
  RFC-0014 + RFC-0033 + RFC-0034
- CONTRACT-001..011: `docs/spec/Nucleor_Error_Codes.md`
- ATOMIC-001..006: `docs/spec/Nucleor_Error_Codes.md`
- DEPTH-001..005: `docs/spec/Nucleor_Error_Codes.md`
- Per-ship CHANGELOG entries: v0.4.244 → v0.5.0
- Spike artifacts: `docs/milestones/spikes/track_g_atomics_2026-04-30.md`,
  `track_h_queues_2026-04-30.md`, `track_i_max_depth_2026-04-30.md`,
  `track_l_perf_cache_2026-04-30.md` (when L lands)

## CHANGELOG window

```
v0.4.238 — strict-mode default flip (3e.3)
…
v0.4.244-258 — RFC-0006 DbC core arc (CONTRACT-001..005 + opt-out + Liskov)
…
v0.4.260-269 — f64 ergonomic wrapper rod arc (9 rods, 77 wrappers)
…
v0.4.271 — CONTRACT-006 (heap-aliased old reject)
v0.4.272 — CONTRACT-008 (result in void-fn ensure)
v0.4.273 — Track G atomics LIVE (ATOMIC-001..005)
v0.4.274 — Track H lock-free queues LIVE
v0.4.275 — CONTRACT-009 (NUCLEOR_DBC_MODE validation)
v0.4.276 — MATCH-012 panic-stutter fix
v0.4.277 — CONTRACT-010 (old in #[require] reject)
v0.4.278 — sequencing doc + heartbeat sync
v0.4.279 — str_char_at_strict opt-in
v0.4.280 — ATOMIC-006 closure+atomic halt (TEMPORARY)
v0.4.281 — AtomicBool ordered ops
v0.4.282 — sequencing doc + heartbeat sync
v0.4.283 — CONTRACT-011 (undefined ident in contract reject)
v0.4.284 — RFC-0033 + RFC-0034 design drafts published
v0.5.0   — Track I (RFC-0014 max_depth) + Track L (perf+cache) integration; cut
```
