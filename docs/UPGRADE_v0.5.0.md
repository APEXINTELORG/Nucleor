# Upgrading to v0.5.0

> **Status:** v0.5.0 cut on 2026-05-01. Verify gate env-off + env-on
> 687 PASS / 0 FAIL. Compiler-IR fixed-point at SHA
> `4372053900a713937651918dc392dd35a184f0a0ef430b6f24f9bfd920eaf84e`.

**TL;DR:** v0.5.0 is the production-robotics + RFC-0006 DbC +
RFC-0007 atomics + RFC-0014 max-depth + content-addressed-cache
release. Upgrade adopter code by:
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

Five atomic types ship as first-class language values:
`AtomicI64`, `AtomicU64`, `AtomicI32`, `AtomicU32`, `AtomicBool`.

`MemOrder` enum carries memory ordering across operations:
`Relaxed`, `Acquire`, `Release`, `AcqRel`, `SeqCst` — these
map directly to LLVM atomic ordering keywords.

Eight `AtomicI64` ops:

```nucleor
let counter: AtomicI64 = atomic_i64(0);
let v: i64 = atomic_load(&counter, MemOrder::Acquire);
atomic_store(&counter, 100, MemOrder::Release);
let prev: i64 = atomic_fetch_add(&counter, 1, MemOrder::SeqCst);
let prev_sub: i64 = atomic_fetch_sub(&counter, 1, MemOrder::SeqCst);
let prev_and: i64 = atomic_fetch_and(&counter, 0xFF, MemOrder::SeqCst);
let prev_or: i64 = atomic_fetch_or(&counter, 0x10, MemOrder::SeqCst);
let prev_xor: i64 = atomic_fetch_xor(&counter, 0x0F, MemOrder::SeqCst);
let cas: Result<i64, i64> = atomic_compare_exchange(&counter, 0, 1,
    MemOrder::SeqCst, MemOrder::Relaxed);
```

LLVM lowering: `load atomic <ord> i64`, `store atomic <ord> i64`,
`cmpxchg ptr <success-ord> <failure-ord>`, `atomicrmw <op> <ord>`.

Five ATOMIC-NNN diagnostics fire on `#[atomic]` violations:

| Code | Catches |
|---|---|
| ATOMIC-001 | Blocking call inside `#[atomic]` function |
| ATOMIC-002 | Allocating call inside `#[atomic]` function |
| ATOMIC-003 | `Cell` / `RefCell` use in `#[atomic]` function |
| ATOMIC-004 | Invalid `compare_exchange` success/failure ordering pair |
| ATOMIC-005 | Invalid memory ordering for atomic load/store |

### RFC-0007 Track H — Lock-free SPSC + MPSC queues (v0.4.274)

Two new lock-free queue rods backed by Track G atomics:

- **`stdlib/rods/spsc_queue.nr`** — single-producer single-consumer
  ring buffer, Lamport-style atomic head/tail bump:
  ```nucleor
  let q: SpscQueue<i64> = spsc_new::<i64>(1024);
  let pushed: bool = spsc_push(&mut q, 42);   // false on full
  let popped: Option<i64> = spsc_pop(&mut q); // None on empty
  ```
- **`stdlib/rods/mpsc_queue.nr`** — multi-producer single-consumer
  with Vyukov-style sequence-number CAS for multi-producer correctness:
  ```nucleor
  let q: MpscQueue<i64> = mpsc_new::<i64>(1024);
  let pushed: bool = mpsc_push(&mut q, 42);
  let popped: Option<i64> = mpsc_pop(&mut q);
  ```

Both rods use AtomicI64 head/tail counters from Track G. SPSC
benchmark: ~1.8M ops/sec uncontended (40,000 ops in ~22ms).

**Capacity-zero is silently normalized to 1** (no diag). Capacity
exhaustion on `push` returns `false` (no panic). No misuse
diagnostics on multi-producer-on-SPSC etc. — those are runtime
contract violations not statically checked.

**Known limitation (deferred to post-v0.5.0):** generic-T
propagation on `Option<T>` match-arm bindings drops `T = str`
when popping an `SpscQueue<str>`. Probe finding
`2026-05-01-generic-T-propagation-spsc-option-str` deferred.
Workaround for now: use `SpscQueue<i64>` and pass packed values.

### RFC-0007 — AtomicBool ordered ops (v0.4.281)

`AtomicBool` shipped in v0.4.273 with constructor + drop only.
v0.4.281 added the load / store / CAS surface delegating to
the underlying `AtomicI64` handle:

```nucleor
let flag: AtomicBool = atomic_bool(false);
atomic_store_bool(&flag, true, MemOrder::Release);
let v: bool = atomic_load_bool(&flag, MemOrder::Acquire);
let cas: Result<bool, bool> = atomic_compare_exchange_bool(
    &flag, false, true, MemOrder::SeqCst, MemOrder::Relaxed);
```

**Closed in v0.5.4:** `atomic_swap_bool` and the typed
`atomic_swap(&AtomicI64, value, order)` now ship. The compiler
intrinsically lowers `atomic_i64_swap_<order>` to
`atomicrmw xchg ptr, i64 v <order>` — no runtime extern hop is
involved, so the AtomicBool wrapper composes through the typed
AtomicI64 helper with the standard false=0/true=1 convention.

```nucleor
let flag: AtomicBool = atomic_bool(false);
let prev: bool = atomic_swap_bool(&flag, true, MemOrder::SeqCst);
// prev == false; flag now true

let counter: AtomicI64 = atomic_i64(0);
let old: i64 = atomic_swap(&counter, 7, MemOrder::AcqRel);
// old == 0; counter now 7
```

All five orderings (Relaxed / Acquire / Release / AcqRel / SeqCst)
are supported on both surfaces.

### RFC-0014 Track I — `#[max_depth = N]` static analysis

`#[max_depth = N]` and `#[max_depth(N)]` annotations on fn
declarations now bound recursion at compile time:

```nucleor
#[max_depth = 100]
fn deep_walk(depth: i64, tree: &Tree) -> i64 {
    if depth >= 100 { return 0; };
    let mut sum: i64 = 0;
    for child in tree.children() {
        sum = sum + deep_walk(depth + 1, &child);
    };
    sum
}
```

The static analyzer proves convergence for the canonical pattern
(visible counter parameter; entry guard `counter >= N` or
`counter > N-1`; recursive call uses a positive counter increment).
The v0.6 analyzer extension also accepts non-first counters,
countdown counters, constant strides such as `depth + 2`, simple
helper-guard predicates, parameter-site `#[no_recurse]` callback
whitelists, and compatible SCCs in the call graph.

Five DEPTH-NNN diagnostics:

| Code | Catches |
|---|---|
| DEPTH-001 | Max-depth analysis cannot bound recursive path |
| DEPTH-002 | Bounded recursion exceeds `#[max_depth = N]` |
| DEPTH-003 | Mutually-recursive `max_depth` cycle violates bounds (also runtime overrun) |
| DEPTH-004 | Invalid `#[max_depth]` attribute placement or value |
| DEPTH-005 | Total stack budget exceeded |

Runtime support: `max_depth_enter(id, limit)` on entry, `max_depth_exit(id)`
on each return path. TLS-backed counters; aborts with `error[DEPTH-003]`
on dynamic overrun.

**Still-conservative surface:**

- callback or function-pointer calls without `#[no_recurse]` on the callback parameter
- recursive calls whose counter update is not a visible positive literal stride or countdown
- helper predicates that do not reduce to `counter >= limit` / `counter > limit`
- SCCs whose member bounds differ or whose cycle edges are not all proven

Adopters hitting these get DEPTH-001 or DEPTH-003 by design. Migration:
rewrite to one of the accepted structural forms or refactor through an
iterative trampoline.

### Track L — Perf baseline + content-addressed compilation cache

Content-addressed cache v2 at `target/.nuc_cache_v2/<prefix>/<sha>.ll`.

**Cache key** is SHA-256 of:
- source content
- compiler version string
- canonical build flags (sorted list)
- strict arithmetic mode (`NUCLEOR_INT_STRICT_INTRIN`)
- DbC mode (`NUCLEOR_DBC_MODE`)

**New CLI**:
- `nuc build --cache-stats` — prints hit/miss counters for the build
- `nuc clean --cache` — manual cache eviction

**Cache correctness** verified against:
- first build stores
- second build hits
- `clean --cache` works
- mtime-only touch: stable (no false invalidation)
- content mutation: invalidates correctly

**Perf measurement infrastructure**:
- `tools/measure_track_l_perf.ps1` — new perf script
- `tools/check_perf_regression.ps1` — switched to scoped process-tree
  memory measurement (was global compiler-process cleanup, which
  miscounted in concurrent test runs)
- `tools/perf_baseline.json` — locked from Track L's measurement set

**Adopter migration:** the cache is opt-in but on by default for
new builds. Existing adopters using `--no-cache` continue working.
Cache miss → falls back to full compilation; no regression.

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

## Migration patterns

### From DbC pre-v0.4.254 manual asserts to RFC-0006 attributes

(Cross-reference `UPGRADE_v0.4.254.md` for the core arc.) v0.5.0's
CONTRACT-006..011 catch additional adopter mistakes that v0.4.254
didn't:

```nucleor
// CONTRACT-006: heap-aliased old() reject
// Before — silent miscompute (i64-ABI aliases pointer):
#[ensure(vec_len(result) == vec_len(old(v)) + 1)]
fn append(v: Vec<i64>, x: i64) -> Vec<i64> { ... }
// After — hoist scalar snapshot:
fn append(v: Vec<i64>, x: i64) -> Vec<i64> {
    let len_initial: i64 = vec_len(v);
    let mut w: Vec<i64> = v;
    vec_push(w, x);
    if vec_len(w) != len_initial + 1 { panic("postcondition violated"); };
    w
}

// CONTRACT-008: result in void-fn ensure (caught at compile)
// Before — silent (luck):
#[ensure(result == 0)]
fn void_fn(x: i64) { print_int(x as i32); }
// After — drop the ensure or add return type:
fn void_fn(x: i64) { print_int(x as i32); }

// CONTRACT-009: invalid NUCLEOR_DBC_MODE (clean diag)
// Before — silent partial-strip:
NUCLEOR_DBC_MODE=off nuc build src.nr
// After — explicit value:
NUCLEOR_DBC_MODE=release nuc build src.nr   # or debug / safe-release / cert / unset

// CONTRACT-010: old() in #[require] (caught at compile)
// Before — misleading clang-link error:
#[require(old(x) > 0)]
fn f(x: i64) -> i64 { x }
// After — move to #[ensure]:
#[ensure(old(x) > 0 && result == x)]
fn f(x: i64) -> i64 { x }

// CONTRACT-011: undefined ident in contract
// Before — clang-link error mentioning a fn that doesn't exist:
#[require(undefined_var > 0)]
fn f(x: i64) -> i64 { x }
// After — typo fix to fn param name:
#[require(x > 0)]
fn f(x: i64) -> i64 { x }
```

### From handle-typed atomic ops to typed AtomicI64

```nucleor
// Before — raw handle, manual ordering passed as i64:
let h: i64 = nuc_atomic_i64_new(0);
nuc_atomic_i64_store_seqcst(h, 42);
let v: i64 = nuc_atomic_i64_load_seqcst(h);

// After — typed AtomicI64 + MemOrder enum:
let counter: AtomicI64 = atomic_i64(0);
atomic_store(&counter, 42, MemOrder::SeqCst);
let v: i64 = atomic_load(&counter, MemOrder::SeqCst);
```

The legacy handle API is still present for back-compat. New code
should use the typed surface.

### From `Vec` polling concurrency to `SpscQueue<T>` / `MpscQueue<T>`

```nucleor
// Before — Vec + manual lock (or worse, racy unlocked):
let mut work_queue: Vec<i64> = vec![];
// producer side: vec_push(&mut work_queue, item);
// consumer side: if vec_len(work_queue) > 0 { let item = vec_pop(&mut work_queue); ... }

// After — lock-free SPSC ring buffer:
import "stdlib/rods/spsc_queue.nr"

let q: SpscQueue<i64> = spsc_new::<i64>(1024);
// producer thread: spsc_push(&mut q, item);  // returns false on full
// consumer thread: match spsc_pop(&mut q) { Some(x) => ..., None => /* empty */ }

// For multi-producer single-consumer:
import "stdlib/rods/mpsc_queue.nr"
let q: MpscQueue<i64> = mpsc_new::<i64>(1024);
```

### From manual recursion-bound asserts to `#[max_depth = N]`

```nucleor
// Before — adopter-managed depth + runtime check:
fn walk(depth: i64, tree: &Tree) -> i64 {
    if depth >= 100 { panic("recursion too deep"); };
    let mut sum: i64 = 0;
    for child in tree.children() {
        sum = sum + walk(depth + 1, &child);
    };
    sum
}

// After — declarative bound, static + runtime check:
#[max_depth = 100]
fn walk(depth: i64, tree: &Tree) -> i64 {
    if depth >= 100 { return 0; };  // entry guard + base case
    let mut sum: i64 = 0;
    for child in tree.children() {
        sum = sum + walk(depth + 1, &child);
    };
    sum
}
```

The declarative form gets DEPTH-001..005 static checks, plus the
runtime depth guard via `max_depth_enter`/`exit`. Adopter writing
the canonical shape gets all of this for free.

### Adopting the content-addressed cache

```bash
# Default: cache is on. First build stores; subsequent rebuilds hit.
nuc build src.nr -o app

# Inspect cache state:
nuc build src.nr -o app --cache-stats
# (prints hit/miss counters for this build)

# Manual eviction:
nuc clean --cache

# Opt out for one build:
nuc build src.nr -o app --no-cache
```

Cache invalidates correctly on source content changes, compiler
upgrade, build-flag changes, strict-mode toggle, or DbC mode
toggle. Mtime-only touches don't trigger invalidation.

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
