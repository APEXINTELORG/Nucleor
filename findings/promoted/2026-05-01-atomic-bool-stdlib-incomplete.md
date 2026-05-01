---
title: `AtomicBool` declared in stdlib has only `atomic_bool()` constructor + `atomic_bool_drop()` destructor — no load/store/CAS/fetch helpers
severity: wrong-error (adopter constructs AtomicBool, can't use it; gets clang-link "undefined function" rather than a clean "feature incomplete")
probe_file: probes/dbc/atomic_bool_basic.nr (will be filed)
diagnostic_actual: clang link error[TYP-005] "undefined function 'atomic_store_bool()'" (and `atomic_load_bool()`)
diagnostic_expected: either (a) ergonomic `atomic_load_bool` / `atomic_store_bool` / `atomic_compare_exchange_bool` helpers shipped, OR (b) `atomic_load`/`atomic_store` polymorphic over AtomicI64/AtomicBool/etc., OR (c) the AtomicBool type marked `#[unimplemented]` until full surface lands
discovered_against: main v0.4.273 (Track G RFC-0007 atomics LIVE)
commit: probe e101dc0 + main ac65419
---

## Repro

```nr
import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let b: AtomicBool = atomic_bool(false);
    atomic_store_bool(&b, true, MemOrder::SeqCst);
    if atomic_load_bool(&b, MemOrder::SeqCst) { print("true"); } else { print("false"); };
    0
}
```

## Actual

```
error[TYP-005]: undefined function `atomic_store_bool()`. ...
COMPILE FAILED (clang exit 1)
```

`atomic_load_bool` similarly missing.

## Stdlib state

`stdlib/rods/atomic.nr` line 15: `struct AtomicBool { handle: i64 }`
Line 177-180: `fn atomic_bool(initial: bool) -> AtomicBool`
Line 182: `fn atomic_bool_drop(a: AtomicBool) -> i64`

That's the entire AtomicBool surface. **No load, store, CAS, fetch_*, swap.** The `handle: i64` is just an `atomic_i64_new(0|1)` — adopters could in principle:

```nr
let b: AtomicBool = atomic_bool(false);
let raw_handle: i64 = b.handle;   // assuming handle is pub or struct fields are reachable
let val: i64 = atomic_load_internal(raw_handle, MemOrder::SeqCst);   // hypothetical
```

…but that defeats the purpose of having a typed AtomicBool.

## Hazard tier

Wrong-error class. Adopter sees a confusing clang-link error pointing at a fn that "should exist" given the AtomicBool type is in scope. Same misleading-phase issue as the closure-sibling-call hazard (Ship 37).

## Suspected fix

Pick one:

**A — ship the missing helpers.** Add `atomic_load_bool` / `atomic_store_bool` / `atomic_compare_exchange_bool` / `atomic_swap_bool` to `stdlib/rods/atomic.nr`. Likely small (each delegates to the AtomicI64 helper passing the underlying handle). Most ergonomic for adopters.

**B — type-polymorphic helpers.** Make `atomic_load`/`atomic_store`/etc. accept any `Atomic*` type via a trait-bound or per-type dispatch. Mirrors Rust's `core::sync::atomic` layout. Larger surface change.

**C — incomplete-feature reject at compile time.** Mark `AtomicBool` with `#[unimplemented]` or add a parse-time TYP-NNN ("AtomicBool not yet supported in v0.4.x — use AtomicI64 with 0/1 convention until v0.5"). Smallest patch, worst UX.

Recommended: **A** — small set of wrapper fns shipped in the same patch as v0.4.273 follow-up.

## Memory-blow-up note

Not memory-related.

## Cross-ref

- v0.4.273 — RFC-0007 atomics LIVE; AtomicBool is partially declared.
- ATOMIC-001..005 diagnostic family — none catches this; this is a stdlib-surface gap, not a contract violation.

## Probe

Filed alongside this finding.


## Promoted

- Fixture: `tests/features/rfc0007_atomic_bool.nr` — load/store/CAS round-trips with bool↔i64 conversion.
- Verify gate step: `t_rfc0007_atomic_bool`.
- Fix shipped: v0.4.281 — option A (ship the missing helpers). Three new fns at `stdlib/rods/atomic.nr:185+`: `atomic_load_bool`, `atomic_store_bool`, `atomic_compare_exchange_bool`. Each delegates to the AtomicI64 ordered helpers via the underlying handle, with bool↔i64 conversion (false=0, true=non-zero) at each boundary. CAS returns `Result<bool, bool>` matching the AtomicI64 shape.
- Deferred: `atomic_swap_bool` — would need new ordered swap helpers (`atomic_i64_swap_relaxed/acquire/release/acqrel/seqcst`); currently only the unordered `atomic_i64_swap` exists. Adopters needing ordered swap on bool should use AtomicI64 with 0/1 convention until the ordered swap runtime helpers ship.
- Promoted: 2026-05-01 by main agent (from probe-agent prep on origin/probe/exploration commit e27ee0a)
