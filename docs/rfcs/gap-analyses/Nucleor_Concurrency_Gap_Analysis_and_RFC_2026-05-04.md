# Nucleor — Concurrency and Data-Race Freedom: Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Companion docs:** Memory safety (active fix), type system, effects, RT
**Disposition:** No file writes were made into `Nucleor_OSS` while drafting this.

---

# Part I — Definitions

## 1.1. The concurrency pillar

Concurrency is its own pillar, not a sub-problem of memory safety. MS-6 (no data race) is one of the eight memory-safety guarantees, but concurrency has additional concerns memory safety does not address: **liveness** (does the system make progress), **fairness** (do all participants get a turn), **ordering correctness** (do atomic operations actually emit the correct hardware semantics), **cancellation** (can work be stopped cleanly), **resource cleanup** (do mutex/channel handles get released).

This document covers thirteen concurrency dimensions: structured concurrency, threads, mutexes, atomics, channels, async/await, actors, capability tokens, effect declarations, cancellation, memory ordering, graph-aware execution policy, and fairness/liveness.

## 1.2. Seventeen concurrency-validation categories (CONC-1 through CONC-17)

Maps to the gap inventory in Part II.

---

# Part II — Gap Analysis

## 2.1. Stated goals

- **RFC-0007 (atomics, target v0.5):** Concrete `AtomicI64`/`AtomicU64`/`AtomicI32`/`AtomicU32`/`AtomicBool`; `MemOrder` with all 5 variants; `Mutex<T>`, `RwLock<T>`, `SpscQueue<T,N>`, `MpmcQueue<T,N>`; `#[atomic]` attribute enforcing ATOMIC-001..005; LLVM lowering of all ordered ops.
- **RFC-0030 (async):** No first-class async in v0.x. Threaded fallback (`async fn` = real OS thread) since v0.2.353. Native async deferred to v0.8.
- **RFC-0035 (Sendable + actors, Draft, v0.9 full):** `Sendable` marker, `actor Name { fields }`, RACE-001..010 diagnostics. First pass v0.6: RACE-001/003/005/008. Full actor runtime serialization deferred.
- **`concurrency.nr` comment:** "All spawned work is scoped — parent always waits for children."

## 2.2. The seventeen gaps

### C-1 — Cancel token is a linker bomb — **CRITICAL**
`cancel_token_new`, `cancel_token_cancel`, `cancel_token_is_cancelled` are LLVM-declared externals with **no C implementation in any runtime file**. Programs calling `cancel_token_new()` will fail to link on Win32 (linker error) or POSIX (undefined symbol). The compiler type-checks calls as returning i64 and registers them in `get_rt_name`, so the compiler accepts code that will not run. **Silent launch blocker for any cooperative cancellation workload.**

### C-2 — POSIX channel is a no-op stub — **CRITICAL**
`__nucleor_channel_new` returns 0 on POSIX. `__nucleor_channel_send` and `__nucleor_channel_recv` are empty functions. **Any program using channels on Linux/macOS silently drops all messages and blocks forever on recv.** Primary inter-thread communication primitive non-functional on POSIX.

### C-3 — Ordered atomic variants have no C runtime backing — **HIGH**
`atomic_i64_load_relaxed`, `atomic_i64_store_release`, etc. are called by the `.nr` stdlib via normal function-call lowering. The C macros only implement unordered variants (`__nucleor_atomic_i64_load`). The ordered names (`__nucleor_atomic_i64_load_relaxed`) are not defined in C. In the LLVM bitcode path the intrinsics are emitted correctly; in the C-compilation fallback path the linker will error out. Real gap in the stated shipping surface.

### C-4 — `conc_map` result collection is a placeholder — **HIGH**
For workloads larger than 4, `conc_map` creates a channel, spawns N threads, joins all, then **pushes literal 0 for each result instead of collecting actual return values**. Documented as a placeholder in the source comment but shipped to users. **Silent miscompute for parallel-map workloads.**

### C-5 — Sendable propagation incomplete for HashMap, closures, tuples, enums — **HIGH**
Per `docs/sendable-inventory.md`: `HashMap<K,V>`, closure-with-captures, `(T1,T2)` tuples, mixed-variant enums all `UNAUDITED`. Compiler silently accepts them when moved across `spawn` boundaries. **Single largest hole in the race-freedom argument** — a `HashMap<String, NonSendableType>` can move into `spawn` with no RACE-001 because the check doesn't reach that case.

### C-6 — RACE-002/004/006/007 have no emission callsites — **HIGH**
All four codes are in `is_known_diag_code` and have explain strings, but no `diag_add_ex(... "RACE-002" ...)` exists anywhere in the compiler. RACE-002 (actor method called without await), RACE-004 (shared mutable state without Mutex/actor), RACE-006 (reentrant actor lock), RACE-007 (deadline under actor await). **Users reading the RFC expect these to fire; they never will.**

### C-7 — Actor runtime serialization entirely absent — **HIGH**
`actor Name { fields }` lowers to `struct Name {}` plus `impl Sendable for Name {}`. There is no mailbox, no message queue, no executor, no method-call interception. Two threads can concurrently call actor methods on the same instance with no interlock. RFC explicitly defers this to v0.9, but the first-pass syntax already ships, **creating the impression of isolation that does not exist at runtime.**

### C-8 — `#[atomic]` attribute not enforced — **MEDIUM**
ATOMIC-001..005 in registry but no emission callsites. A function marked `#[atomic]` can allocate, block on a mutex, or call `thread_join` without diagnostic.

### C-9 — `scope { spawn { ... } ... }` syntax entirely absent — **MEDIUM**
RFC examples use this syntax; compiler comments (v0.3.138) note it was removed because the parse branch was dead. Tools-suite scanner detects literal string `"scope {"` for effect inference but it's dead for the main compiler. The "parent always waits for children" claim is only true if the user manually calls `conc_join` for every handle.

### C-10 — Thread pool barrier not implemented — **MEDIUM**
`thread.nr` header advertises "Thread pool, futures, parallel map, barrier." Pool/futures/parallel-map exist; **no `nuc_barrier_new`/`nuc_barrier_wait`** anywhere. Parallel algorithms requiring mid-computation rendezvous have no stdlib barrier.

### C-11 — Mutex resource leak — no destroy path — **MEDIUM**
`conc_mutex()` allocates `CRITICAL_SECTION`/`pthread_mutex_t`; **no `conc_mutex_destroy`/`mutex_free`**. Long-running programs leak both OS handle and heap allocation. No RAII drop integration. (Cross-references G-1 in memory safety.)

### C-12 — Closure capture table is not thread-safe — **HIGH**
`g_capture_table[8192][32]` is a global static accessed without synchronization. Two threads simultaneously invoking different closures with the same `clo_id` race on the same slot. **Source comment acknowledges this** ("Calling the same closure from multiple threads with different capture values is undefined") but no compiler diagnostic fires. Practical race bypass for any concurrency code that uses closures — which is most.

### C-13 — `ambient_scheduler()` is unimplemented — **MEDIUM**
`__nucleor_ambient_scheduler` declared in LLVM IR header, registered in `get_rt_name`, **no C implementation**. No propagation check requires `SchedulerCap` for spawning. Capability token exists as a type name only.

### C-14 — Effect system for concurrency entirely unshipped — **MEDIUM**
`pure fn` / `requires [sync.schedule]` / `requires [sync.channel]` recognized in tools-suite scanner but not enforced by main compiler. Quarantined tests in `_unimplemented/`. No no-spawn-in-pure or no-channel-in-deadline check at compile time. (Cross-references the effects RFC.)

### C-15 — `async_spawn` registry cap fixed at 256 — **LOW**
`NUC_ASYNC_REGISTRY_SIZE 256` hard-coded; >256 in-flight async tasks `exit(1)`s. Process-killing panic, not structured error. No adopter-visible way to configure.

### C-16 — Channel close semantics absent — **LOW**
No `channel_close`/`channel_drop`. Closed-sender scenario (producer exits, consumer still calling `recv`) blocks forever. Standard producer/consumer "done" signal not implementable through the channel type.

### C-17 — AtomicU64/I32/U32/AtomicBool have no typed ordered ops — **LOW**
Only `AtomicI64` and `AtomicBool` have full ordered API. Other widths have `new`/`drop` only; users must drop to the raw `a.handle` field for ordered ops, defeating type safety.

## 2.3. Cross-cutting risks

- **Sendable + heap-alias blindness compound:** Even when HashMap Sendable propagation is audited, lack of aliasing analysis means a Sendable-marked value may share heap-allocated backing store with a non-Sendable alias. Sendable says "safe to move" but if backing store is still reachable on the originating thread, the guarantee is hollow.
- **Closure capture table race:** any concurrency test involving closures is testing on an already-racy foundation. Closure-based worker patterns — the most common — are silently unsafe regardless of Sendable checks.
- **"Syntax accepted but not enforced" trust issues:** `#[atomic]`, `actor` methods, `requires [sync.schedule]` — three categories simultaneously documented, accepted, and unenforced.
- **Win32 Interlocked is always SeqCst (C-path); LLVM path is correct:** Lock-free code relying on Relaxed/Release/Acquire discipline measures correctly via LLVM. C-path measurements are over-synchronized and mask ordering bugs.
- **POSIX channel stub makes cross-platform testing impossible:** Linux CI tests against no-op functions. Windows-only findings don't transfer to POSIX.

---

# Part III — RFC

## 3.1. Goals

1. Close the two CRITICAL launch blockers (C-1, C-2) immediately.
2. Make the actor and Sendable story honest — either ship enforcement or don't claim it.
3. Restore POSIX parity so concurrency code is portable.
4. Track liveness, fairness, and ordering correctness as named concerns.

## 3.2. Closure plan, by gap

### C-1 (cancel token linker bomb) — Phase 1 emergency
Implement `__nucleor_cancel_token_new`/`_cancel`/`_is_cancelled` in `nucleor_llvm_rt.c`. Simple atomic flag. POSIX uses pthread mutex for the flag store; Win32 uses Interlocked. Add cancel-token smoke test to verify gate.

### C-2 (POSIX channel stub) — Phase 1 emergency
Implement POSIX channel with pthread mutex + condvar. Mirror the Win32 semantics (bounded FIFO, blocking send/recv). Add cross-platform channel smoke test. **Block any v0.7+ release until this lands.**

### C-3 (ordered atomics no C backing) — Phase 1
Add `__nucleor_atomic_*_relaxed/acquire/release/acq_rel/seq_cst` C wrappers. On Win32 they all map to Interlocked (over-synchronized but correct); on POSIX they use C11 `<stdatomic.h>` with proper memory_order arguments. The LLVM-bitcode path remains the preferred path; this closes the C-path fallback.

### C-4 (conc_map placeholder) — Phase 1
Replace placeholder with actual result collection. Workers send results through the channel; main thread receives N results into the result Vec. Add fixture test that verifies non-zero results.

### C-5 (Sendable propagation gaps) — Phase 2
Audit each currently-UNAUDITED type:
- `HashMap<K, V>`: Sendable iff K Sendable and V Sendable
- `(T1, T2)`: Sendable iff all elements Sendable
- Closure with captures: Sendable iff all captures Sendable
- Mixed-variant enums: Sendable iff all variants' payloads Sendable
Implement the propagation in the compiler's Sendable check. Update `docs/sendable-inventory.md` to AUDITED for each. Add per-type negative test confirming RACE-001 fires when a non-Sendable type crosses spawn.

### C-6 (RACE-002/004/006/007 unemitted) — Phase 2
For each:
- RACE-002 (actor method without await): emit when call to actor method is not preceded by `await` (only meaningful once C-7 ships)
- RACE-004 (shared mutable state without Mutex/actor): emit when two `spawn` blocks each capture the same mutable reference to the same value without it being inside Mutex or actor
- RACE-006 (reentrant actor lock): emit when an actor method directly or transitively calls itself
- RACE-007 (deadline under actor await): emit when `#[deadline]` fn calls `await` on an actor

### C-7 (actor runtime serialization absent) — Phase 3
Implement actor mailbox + executor:
- Each actor instance has a per-instance message queue (mutex-protected)
- Method calls on an actor enqueue a message rather than execute directly
- A single executor thread per actor (or shared executor pool) drains the mailbox
- Actor methods serialized by construction; no two methods on the same instance run concurrently
- `await` on actor method: caller blocks until the message is drained and the result returned

### C-8 (`#[atomic]` not enforced) — Phase 2
Implement the ATOMIC-001..005 enforcement pass. Source-text or AST scan inside `#[atomic]` fn bodies for: alloc calls (ATOMIC-001), mutex calls (ATOMIC-002), thread_join (ATOMIC-003), I/O (ATOMIC-004), panic (ATOMIC-005).

### C-9 (`scope { spawn { ... } }` absent) — Phase 2
Restore the `scope` block as a true structured-concurrency primitive. Parse the block; collect all `spawn` calls within; emit a join-all at the closing brace. Compiler-enforced "parent always waits for children." Test fixture confirming a `scope` block joins all spawns at exit.

### C-10 (no barrier) — Phase 2
Add `nuc_barrier_new(n)` / `nuc_barrier_wait(b)` / `nuc_barrier_free(b)` runtime functions. Win32: counting semaphore + mutex; POSIX: pthread barrier. Wire into `thread.nr` per the header advertisement.

### C-11 (mutex resource leak) — Phase 1
Add `conc_mutex_destroy` / `mutex_free`. **Cross-references memory-safety G-1** (auto-drop) — eventually the Mutex type implements Drop and cleanup is automatic.

### C-12 (closure capture table not thread-safe) — Phase 1 (CRITICAL despite MEDIUM-rated dimension)
Two options:
- **Option A:** make `g_capture_table` access mutex-protected. Slow but safe.
- **Option B:** per-thread capture table (TLS-based). Fast but requires per-thread cleanup.
Recommendation: Option A immediately, Option B for v1.0.
Until fixed, add diagnostic when a closure with captures is moved into `spawn` (warning that capture table is shared-mutable).

### C-13 (`ambient_scheduler` unimplemented) — Phase 2
Implement `__nucleor_ambient_scheduler` returning a process-global capability token. Add propagation check: any function calling `spawn` requires `SchedulerCap` parameter. (Cross-references effect-system RFC.)

### C-14 (effect system for concurrency unshipped) — Phase 3
Cross-references the effects RFC. Once the effect system is real, concurrency-effect rules (no-spawn-in-pure, no-channel-in-deadline) become enforceable.

### C-15, C-16, C-17 — Phase 2-3 polish
- C-15: configurable async registry size; structured Result-Err on overflow
- C-16: channel_close primitive + closed-channel semantics on send/recv
- C-17: full ordered API for AtomicU64/I32/U32

## 3.3. Phasing summary

| Phase | What lands | Closures |
|---|---|---|
| **Phase 1 (emergency)** | Cancel token impl, POSIX channel impl, ordered atomic C backing, conc_map fix, mutex destroy, closure-table mutex | C-1, C-2, C-3, C-4, C-11, C-12 |
| **Phase 2** | Sendable propagation audit, RACE-002/004/006/007 emission, #[atomic] enforcement, scope block, barrier, ambient_scheduler impl | C-5, C-6, C-8, C-9, C-10, C-13, C-15, C-16, C-17 |
| **Phase 3** | Actor mailbox + executor, full effect-system integration | C-7, C-14 |

## 3.4. v1.0 release gate

Phases 1 and 2 complete for all CRITICAL and HIGH gaps. Phase 3 (actor runtime, full effect integration) acceptable to defer to v1.x if first-pass actor enforcement (RACE-002/006) is in place.

## 3.5. Open questions

1. POSIX channel implementation choice: pthread mutex+condvar (POSIX-portable) or eventfd (Linux-fast)? Recommendation: pthread for portability; eventfd as future optimization.
2. Actor executor model: per-actor thread (simple, but doesn't scale) or shared work-stealing pool (scales but complex)? Recommendation: per-actor thread for first ship, work-stealing for v1.x.
3. Closure capture table: does Option B (TLS) require changes to the closure-passing ABI? If yes, defer to v1.0; if no, ship in Phase 2.

---

# Part IV — Disposition

**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
