---
title: `async_await(<bogus_handle>)` (any non-spawn-issued i64 value) → **STATUS_ACCESS_VIOLATION** segfault. Sister to async_await-twice heap-corruption hazard — both are use-after-free / unvalidated-pointer-dereference class.
severity: crash (memory-safety class — segfault from unvalidated pointer)
probe_file: probes/async/await_invalid_handle.nr (will be filed)
diagnostic_actual: `nuc run: child exited rc=-1073741819 from ... .exe` — that's Windows STATUS_ACCESS_VIOLATION (0xC0000005). No Nucleor-side panic.
diagnostic_expected: clean PANIC with adopter-friendly message: `PANIC: async_await: handle <value> is not a valid spawn handle` OR a more general handle-validity check at the runtime helper boundary.
discovered_against: main v0.5.22 (probe just-rebased)
commit: probe (post-rebase) + main a74b160
---

## Repro

```nr
import "stdlib/rods/async.nr"

fn main() -> i32 {
    let h: i64 = 999999;        // ← any non-spawn-issued value
    let r: i64 = async_await(h);
    print_int(r as i32);
    0
}
```

## Actual

```
nuc run: child exited rc=-1073741819 from target\...exe
```

`-1073741819 = 0xC0000005 = STATUS_ACCESS_VIOLATION`. The async_await helper dereferences the i64 as a thread-handle pointer without validation, faults on the bogus address.

## Sister hazard

This is the simpler-shape sister of `2026-05-01-async-await-twice-heap-corruption.md` (filed previous tick):

| Bad call | Crash |
|---|---|
| `async_await(h)` twice on valid handle | STATUS_HEAP_CORRUPTION (0xC0000374) — use-after-free |
| `async_await(<garbage_int>)` | STATUS_ACCESS_VIOLATION (0xC0000005) — bad-pointer-deref |

Both classes share root: the async runtime trusts the i64 handle without validation.

## Hazard tier

**Crash, memory-safety class**. Adopter logic that constructs a handle value from external data:

```nr
let h: i64 = config_lookup("worker_handle");   // user-supplied
let r: i64 = async_await(h);                    // segfault on bad config
```

…or simply typo'd:

```nr
let h: i64 = async_spawn(work, args);
let r: i64 = async_await(h + 0);   // accidentally modified the handle
```

…produce non-deterministic crashes. The user mandate "always look for memory blow ups and stop the process if that happens" requires the runtime to catch this at the Nucleor PANIC layer, not let the OS raise STATUS_ACCESS_VIOLATION.

## Suspected fix

In `stdlib/rods/async.nr` (or the runtime helper backing `async_await`):

1. Maintain a registry of valid spawn handles (e.g. `Vec<i64>` of issued handle ids, or a HashMap<i64, ThreadState>).
2. On `async_await(h)`:
   - Validate `h` is in the registry.
   - If not: `panic("async_await: handle " + str_from_int(h) + " is not a valid spawn handle (not issued by async_spawn or already consumed)");`
   - If yes: proceed with the join; mark consumed (closes the double-await sister hazard too).

Single registry covers both this hazard and the double-await one.

## Memory-blow-up note

Direct hit on user mandate. STATUS_ACCESS_VIOLATION is the canonical "memory blow up" — process tries to deref bad pointer, OS terminates. Currently Nucleor lets this through to the OS instead of catching at the language runtime.

## Cross-ref

- 2026-05-01-async-await-twice-heap-corruption.md — sister hazard (same registry would close both)
- v0.5.19 — ASYNC-001 + async_spawn / async_await stdlib documented; the docs should reference handle-validity contract
- ATOMIC-006 closure+atomic temporary halt — async/atomic family has multiple memory-safety surfaces

## Probe

`probes/async/await_invalid_handle.nr` — minimal repro.


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
