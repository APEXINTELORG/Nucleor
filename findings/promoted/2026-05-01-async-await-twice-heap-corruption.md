---
title: `async_await(h)` called twice on the same handle → **STATUS_HEAP_CORRUPTION** (rc=-1073740940 = 0xC0000374). Adopter writing canonical Rust pattern of awaiting twice gets silent heap corruption.
severity: crash (memory-safety hazard — heap corruption is critical)
probe_file: probes/async/await_twice_heap_corruption.nr (will be filed)
diagnostic_actual: `nuc run: child exited rc=-1073740940 from target\p3_double_await.exe` — that's Windows STATUS_HEAP_CORRUPTION (0xC0000374). No Nucleor-side panic message.
diagnostic_expected: either (a) idempotent await — second await returns cached result, OR (b) clean PANIC: handle already awaited, OR (c) clean compile-time reject if ownership tracking can detect double-await
discovered_against: main v0.5.21 (probe just-rebased)
commit: probe (post-rebase) + main 3ed4bbe
---

## Repro

```nr
import "stdlib/rods/async.nr"

fn worker(x: i64) -> i64 { x }

fn main() -> i32 {
    let h: i64 = async_spawn(worker, 42);
    let r1: i64 = async_await(h);
    let r2: i64 = async_await(h);   // ← second await on same handle
    print_int(r1 as i32);
    print_int(r2 as i32);
    0
}
```

## Actual

```
nuc run: child exited rc=-1073740940 from target\p3_double_await.exe
```

`-1073740940 = 0xC0000374 = STATUS_HEAP_CORRUPTION`. Windows raised the crash. Output never reached. No Nucleor-side panic.

## Hazard tier

**Crash, memory-safety class**. Heap corruption is the worst kind of runtime failure — the process state is undefined post-corruption, and downstream code may continue running with corrupted state if the runtime catches the crash and ignores it.

For the v0.5.19 ASYNC-001 ship that pointed adopters at `async_spawn` / `async_await`, this hazard fires immediately after canonical adopter usage. Adopter pattern:

```nr
let h: i64 = async_spawn(work, args);
let r: i64 = async_await(h);
log("first call:", r);
// ... time passes ...
let r2: i64 = async_await(h);   // ← assumed idempotent; CORRUPTS HEAP
log("retry:", r2);
```

This is the kind of pattern adopters write without thinking about ownership semantics.

## Suspected fix

In `stdlib/rods/async.nr` `async_await(handle)` runtime helper:

1. After joining the OS thread + reading the result, mark the handle's slot as "consumed".
2. On subsequent calls with the same handle:
   - **Option A (idempotent)**: return the cached result. Adopter UX best.
   - **Option B (panic)**: emit `PANIC: async_await: handle already awaited`. Forces correct ownership.
   - **Option C (compile-time)**: track handle ownership at type-check; reject double-await statically. Best long-term but requires move semantics in Nucleor.

Recommended: **B** for v0.5.x (defensive runtime panic), **C** for v0.6+ when ownership infrastructure lands.

The current behavior (free the thread state on first await, then read freed memory on second await) is what causes the heap corruption — classic use-after-free.

## Memory-blow-up note

Direct hit on the user mandate "always look for memory blow ups and stop the process if that happens". The Nucleor runtime currently fails this case by allowing heap corruption to surface to the OS rather than catching it at the Nucleor level.

## Cross-ref

- v0.4.205 — for-loop vec_len snapshot (sister memory-safety class fix from probe sweep)
- v0.5.19 — ASYNC-001 ship that pointed adopters at this stdlib; the docs should also note the await-once contract
- 2026-04-30-vec-allocation-without-drop-leaks.md — sister memory-safety hazard family
- ATOMIC-006 closure+atomic temporary halt — async family has its own memory hazards too

## Probe

`probes/async/await_twice_heap_corruption.nr` — minimal repro.


## Promoted

- Fix shipped: v0.5.25 — handle-validation registry in
  `__nucleor_async_spawn` / `__nucleor_async_await` (both
  Win32 and POSIX paths). Each spawn registers the handle in
  a fixed-capacity (256-slot) thread-safe array; each await
  checks the registry BEFORE dereferencing.
- Failure modes pre-fix:
  - Double-await: free()'d memory dereferenced → heap corruption.
  - Bogus handle: arbitrary i64 dereferenced as NAsyncTask* →
    access violation segfault.
- Now both panic cleanly with adopter-friendly messages naming
  the bogus value:
  - `PANIC: async_await: handle <N> is not a valid spawn handle
    (already awaited, or not from async_spawn). Each handle may
    be awaited exactly once.`
- Registry is mutex-protected; 256 concurrent tasks is well above
  practical fan-out for v0.5. PANIC at registration if full
  (clean message naming the cap).
- Validation: probe's repros now panic-with-rc=1 instead of
  crash-with-Windows-status-codes (rc=-1073740940 heap
  corruption / rc=-1073741819 access violation). Normal
  spawn→await→result flow unchanged.
- Promoted: 2026-05-01 by main agent (probe commits b2a12f6 + e365dab).
