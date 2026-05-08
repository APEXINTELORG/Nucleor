# RECON Pass-1 Audit — Concurrency / send-sync runtime + RT primitives (Layer 5)

**Date:** 2026-05-08
**Scope:** Concurrency primitives in stdlib (atomic, thread, channel, mutex, barrier, SpscQueue, MpscQueue), Send/Sync at runtime, RT attributes (RFC-0001 `#[no_alloc] / #[no_panic] / #[no_dyn] / #[deadline]`), `#[atomic]` (RFC-0007), `#[isr]` (RFC-0008), Heptane WCET (RFC-0009). Verify pass — find what verify is missing.
**Binary:** `bin/nucleor.exe` v1.0 (path: `Nucleor_OSS_integrate_r05_with_row_v0842`)
**Methodology:** Source-level review of `.nr` rod APIs, `_rt.c` runtime code, RFC compliance check, and live compile/run probes through `audit_scratch_concurrency/t01..t36`. NO source modifications. NO verify.sh.
**Out of scope:** G-6 Sendable language rules (Layer 4), parser, type system, codegen, macOS.

---

## Inventory

### Concurrency rods (.nr)

| Rod | Lines | Backing runtime |
|---|---|---|
| `stdlib/rods/atomic.nr` | 465 | LLVM atomic intrinsics (compiler-emitted) + `__nucleor_atomic_i64_*` raw-handle helpers in `nucleor_llvm_rt.c` |
| `stdlib/rods/thread.nr` | 39 | `stdlib/runtime/thread_rt.c` (~352 LOC) |
| `stdlib/rods/concurrency.nr` | 112 | wraps `__nucleor_mutex_*`, `__nucleor_channel_*`, `thread_spawn`, etc. |
| `stdlib/rods/spsc_queue.nr` | 70 | pure-Nucleor over `AtomicI64` + `Vec<Option<T>>` |
| `stdlib/rods/mpsc_queue.nr` | 105 | pure-Nucleor over `AtomicI64` + `Vec<Option<T>>` |

### Runtime helpers

- `stdlib/runtime/nucleor_llvm_rt.c` — `__nucleor_mutex_*`, `__nucleor_channel_*`, `__nucleor_atomic_*` (legacy), `__nucleor_atomic_i64_*` (raw-handle), `__nucleor_deadline_check`.
- `stdlib/runtime/thread_rt.c` — thread pool, futures, parallel map, reusable barrier.
- LLVM atomic ops (`load atomic`, `store atomic`, `cmpxchg`, `atomicrmw`) are emitted directly by the compiler for ordered `AtomicI64` ops; verified by inspecting `audit_scratch_concurrency/.../t01_atomic_basic.ll`.

### RT-attribute enforcement

`compiler/nucleor_s1_compiler.nr` carries the `enforce_no_alloc`/`enforce_no_panic`/ISR scanner. The compiler ships an `info[RT-G135]` disclosure in every build that tells adopters which surfaces are known-incomplete (depth-bounded helper scan, no fn-pointer reach, no closure reach, no certified WCET, no embedded sysroot). The audit treats this disclosure as *honest documentation of incomplete enforcement*, but each gap below is still a real adoption hazard the verify suite does not exercise.

### Existing tests

- `tests/features/rfc0007_*` — atomic basic / orderings / width wrappers / queue (all pass).
- `tests/features/thread_smoke.nr`, `thread_barrier_smoke.nr`, `concurrency_*_smoke.nr` — lifecycle only, no contention.
- `tests/err/err_atomic_001..005`, `err_isr_001..008`, `err_no_alloc_*`, `err_no_panic_*` — neg-paths for diagnostics.
- **Gap:** no contention test. No multi-threaded SpscQueue / MpscQueue stress. No deadline mid-execution-trap test. No double-drop / use-after-free / forged-handle test. No platform-divergence (Windows CRITICAL_SECTION vs POSIX pthread_mutex) test.

---

## Coverage map (probes run)

| ID | Axis | Subject | Result |
|---|---|---|---|
| t01 | Functional | AtomicI64 load/store/fetch_add | PASS |
| t02 | Adversarial | AtomicI64 use-after-free via reconstructed handle | **CRASH (rc=224)** |
| t03 | Adversarial | AtomicI64 double-drop | **CRASH (heap)** |
| t04 | Attack | AtomicI64 with forged handle (12345) | **SEGV** |
| t05/06/07 | Diagnostic | `#[no_alloc]` body with `Vec::with_capacity` / `Box::new` | **MISSED (no error)** |
| t08 | Diagnostic | `#[no_panic]` with `1.0/dt` | RT-009 warning only (float div: not actually a panic source) |
| t09 | Diagnostic | `#[no_panic]` with array OOB `v.get(1000)` | **MISSED** |
| t10 | Edge | `#[deadline = 1ns]`, `0us`, `9999999999999s` | All silently accepted |
| t11/t12 | Edge | `#[deadline = 1us]` overrun → 38ms run before exit | DETECTION ONLY (no mid-execution trap) |
| t13 | Diagnostic | `atomic_load(.., Release)` | ATOMIC-005 fires correctly |
| t14/t15 | Diagnostic | CAS Acquire/AcqRel + Release/SeqCst | ATOMIC-004 fires correctly |
| t16 | Stress | 8 threads × 10 000 fetch_add | PASS (counter = 80 000) |
| t17 | Edge | `spsc_new(0)` capacity normalize | PASS (cap=1) |
| t18 | Edge | SPSC wrap 100 push/pop on cap=4 | PASS |
| t19 | Diagnostic | `#[isr]` with param | ISR-001 fires |
| t20 | Diagnostic | `#[isr]` with `Vec::new` | RT-001 fires (ISR alloc inheritance OK) |
| t21 | Composition | `#[isr]` calling `conc_lock` (mutex via wrapper) | **MISSED** |
| t22 | Composition | `#[atomic]` calling `conc_lock` | **MISSED** |
| t23 | Composition | `#[atomic]` calling extern `mutex_lock` direct | ATOMIC-001 fires |
| t24 | Composition | `#[atomic]` calling `conc_recv` (blocking channel) | **MISSED** |
| t25 | Functional | barrier reusable (3 wait calls, parties=1) | PASS |
| t26 | Diagnostic | `#[isr, deadline = 100us]` (combined attr group) | **MISSED** (separate-attr form fires ISR-002) |
| t27 | Composition | `#[no_alloc]` calling unannotated same-file allocator | RT-001 fires (transitive scan works at depth 1) |
| t28 | Adversarial | `#[no_alloc]` calling unannotated allocator via fn-ptr | **MISSED** |
| t29 | Adversarial | helper chain depth 10 inside `#[no_alloc]` | **MISSED** (depth-8 bound exceeded) |
| t30 | Functional | MpscQueue push/pop 5 ints | PASS |
| t31 | Stress | mutex acquire/release × 10 000 single-thread | PASS (49 ms) |
| t32 | Cross-platform | recursive `conc_lock` × 2 same thread | PASS on Windows, **would deadlock on POSIX** |
| t33 | Diagnostic | `#[no_alloc]` calling unannotated extern fn | **MISSED** (RT-005) |
| t34 | Diagnostic | channel: send(0), close, recv → both return 0 | Ambiguous |
| t35 | Adversarial | thread_future_get called twice on same handle | **CRASH (heap)** |
| t36 | Edge | `thread_pool_new(0)` | Silently normalized to 1 |

---

## Findings

### F-CONC-001 — Atomic raw-handle layer is unsound: reconstructed/forged/freed handles cause UAF and SEGV  [CRITICAL]

**Location:** `stdlib/rods/atomic.nr` lines 11-15 (`AtomicI64 { handle: i64 }`), `stdlib/runtime/nucleor_llvm_rt.c` lines 7758-7813 (`__nucleor_atomic_i64_*`).

**Evidence:**

- The handle is just an `i64` cast to `long long *`. There is no opacity, no provenance check, no liveness tracking.
- `t02_atomic_use_after_free.nr` constructs `AtomicI64 { handle: h }` from a saved `i64` after `atomic_i64_drop`, calls `atomic_load(&zombie, ...)` → child exits rc=224 (UAF / heap corruption).
- `t03_double_drop.nr` drops the same backing pointer twice (via two `AtomicI64` structs sharing one `handle: i64`) → `nuc run: child exited rc=-1073740940` (Windows heap corruption fast-fail, 0xC0000374).
- `t04_atomic_arbitrary_ptr.nr` constructs `AtomicI64 { handle: 12345 }`, runs `atomic_load` → SIGSEGV (rc=139).

The struct field `handle` is publicly accessible (no privacy modifier on `AtomicI64`), and `AtomicI64` is constructible from any `i64` literal, so any program can fabricate a handle.

**Severity:** CRITICAL — programs containing only safe-looking Nucleor source can crash via UAF or arbitrary memory access. There is no `unsafe` keyword required to wield this attack surface.

**Remediation:**

1. Make `AtomicI64.handle` private; expose only via a constructor + method API. Forbid struct-literal construction of `AtomicI64 { handle: ... }` from outside the rod (or behind an `unsafe` gate when the language gains one).
2. Add a runtime liveness sentinel: store handles in a slab or a generation-tagged table. `__nucleor_atomic_i64_load` checks the generation; mismatch returns a sentinel (0) and emits a one-shot diagnostic to stderr.
3. As a fallback if (1) is not v1-feasible, document the unsoundness explicitly in `atomic_limitations()` and add `#[unsafe_handle]`-style attribute to `AtomicI64` so adopters get a warning when they touch `.handle`.
4. Same hazard applies to channel handles (`__nucleor_channel_*`), mutex handles (`__nucleor_mutex_*`), thread-pool handles, future handles, barrier handles. The whole "i64 = pointer" pattern is one mistake away from arbitrary-write. RFC-0061 (handle-table) work would close this; until then it is the single largest concurrency-soundness gap.

---

### F-CONC-002 — `thread_future_get` double-free crashes the process  [CRITICAL]

**Location:** `stdlib/runtime/thread_rt.c` lines 200-216.

**Evidence:**
```c
long long nuc_future_get(long long fut_h) {
    Future *fut = (Future *)(void *)fut_h;
    if (!fut) return 0;
    ...
    free(fut);     // freed on first call
    return result;
}
```
There is no flag clearing the handle, no double-call protection. `t35_future_double_get.nr` calls `thread_future_get(f)` twice → `nuc run: child exited rc=-1073740940` (heap corruption).

Compounding: per `concurrency.nr` `thread_limitations()` disclosure, "a panic in a submitted fn aborts the worker thread and may leave the future-handle leaked". A Nucleor program that wraps `future_get` in any retry loop walks straight into this UAF.

**Severity:** CRITICAL — the canonical way to consume a result is now a UAF foot-gun.

**Remediation:**

1. Add an idempotent `consumed` flag to `Future`. First `nuc_future_get` returns the result and frees; second call returns 0 (or a sentinel) and emits a diagnostic.
2. Document in `thread.nr` that the future handle is single-consume and provide `thread_future_try_get` (returns `Option<i64>`) for the polling path.
3. Pair with F-CONC-001's handle-table proposal — one fix subsumes both.

---

### F-CONC-003 — `#[deadline]` runtime check is post-hoc; no mid-execution trap  [HIGH]

**Location:** `stdlib/runtime/nucleor_llvm_rt.c` lines 6140-6158 (`__nucleor_deadline_check`).

**Evidence:**

- The compiler injects a single check at function exit that compares `now - start_us` to `limit_us` and `exit(1)` on overrun. RFC-0001 §3.2.4 says deadline is enforced "at runtime by a hardware-timer trap"; the implementation is a post-hoc compare.
- `t12_deadline_no_midexec.nr`: `#[deadline = 100us]` function runs a 50M-iteration loop (~38 ms), then exits, then prints `RT-004` *after the work is done*. Total elapsed ≈ 38400× the deadline before any signal. A real-time control loop that overruns its budget by 38 000 % cannot meet RT semantics.
- For an infinite loop or unbounded work, the deadline never fires at all (function never returns).

**Severity:** HIGH — deadline is a *detector*, not an *enforcer*. The pitch in RFC-0001 §1 ("safer than Rust at runtime, because no_alloc/no_panic/no_dyn/deadline are first-class") cannot be substantiated for the deadline axis on the v1.0 implementation.

**Remediation:**

1. Wire a real timer:
   - Linux: `timer_create(CLOCK_MONOTONIC) + timer_settime + SIGALRM` handler that sets a flag the function entry-block reads on subsequent loop iterations, or directly raises a recoverable trap.
   - Windows: `CreateTimerQueueTimer` → APC that posts a thread-context-cancel.
2. Codegen: emit a per-loop-back-edge poll of the trap flag inside `#[deadline]` functions. (Trade-off: poll overhead in tight loops; document and let the user disable per RFC-0001 `#[allow(...)]`.)
3. Until (1)/(2) ship, downgrade the RFC status from "Implemented" to "Implemented (post-hoc detection only)" in RFC-0001 row 7, and add a `RT-G3a` disclosure pointing at this gap.

---

### F-CONC-004 — `#[no_alloc]` substring scanner misses RFC-listed canonical patterns  [HIGH]

**Location:** `compiler/nucleor_s1_compiler.nr` `enforce_no_alloc` (substring match per RT-G135 disclosure).

**Evidence:**

RFC-0001 §3.2.1 explicitly lists `Vec::with_capacity(n)`, `Box::new(x)`, `String::new`, `HashMap::insert` (resize), `vec_push` (grow) as forbidden. The current scanner detects `Vec::new(` and `.push(` substrings only.

- `t06_no_alloc_with_capacity.nr` — `Vec::with_capacity(1024)` inside `#[no_alloc]` — compiles silently.
- `t07_no_alloc_box_new.nr` — `Box::new(42)` inside `#[no_alloc]` — compiles silently.
- `t09_no_panic_oob.nr` — `v.get(1000)` (panicking-on-OOB) inside `#[no_panic]` — compiles silently. Per RFC-0001 §3.2.2 array OOB is the canonical panic source, but RT-002 only fires on arithmetic `/` and `%`.
- `t28_no_alloc_fn_ptr_escape.nr` — calling allocating fn through `let f: i64 = ... as i64; f()` — compiles silently. Disclosure acknowledges fn-ptr escape, but it is still a soundness gap.
- `t29_no_alloc_deep_chain.nr` — 10-deep helper chain ending in `Vec::new` — compiles silently. Depth-8 bound documented but adopter-hostile (one small refactor breaks the guard).
- `t33_no_alloc_ffi.nr` — `extern fn malloc_dummy(n: i64) -> i64` called from `#[no_alloc]` fn — RT-005 (FFI-without-`#[ffi_no_*]`) does NOT fire. RFC-0001 §3.5 says every extern fn is treated as `may_alloc, may_panic, may_dispatch_dyn` by default; current compiler does not enforce this.

The RT-G135 disclosure is honest about all of these gaps. Listing them here so the verify gap is visible — the test suite has no negative test for `Vec::with_capacity` / `Box::new` / array OOB / fn-ptr / depth-9 / FFI-without-attr.

**Severity:** HIGH — `#[no_alloc]` and `#[no_panic]` are **the** v0.3/v1.0 marquee features. A user reads the RFC, writes the canonical pattern (`Vec::with_capacity` is the natural way to pre-allocate), thinks the compiler protects them, and ships. The compiler did not protect them.

**Remediation (priority order):**

1. Extend the `#[no_alloc]` substring set to cover the full RFC-0001 §3.2.1 list: `Vec::with_capacity`, `Box::new`, `String::new`, `String::from`, `HashMap::new`, `HashMap::insert`, `BTreeMap::new`, `BTreeMap::insert`, `Vec::resize`, `Vec::extend`. Same for `String`. Mirror in tests/err.
2. Extend the `#[no_panic]` scanner to flag `vec.get(literal)` without prior length check, array index `[i]`, `.unwrap`, `.expect`, `panic!`, `unreachable!`, `assert!`. Today RT-002 covers a thin subset.
3. Wire RT-005 (FFI without `#[ffi_no_alloc]`) — extern-fn declarations without RT trust attributes called from a `#[no_alloc]` fn must error. This is the cheapest of the four — the parser already knows where extern decls live.
4. Move from substring scan to AST visit. Sound enforcement requires walking the resolved IR, not the source text. The depth-8 limit, fn-ptr escape, and closure escape all dissolve at the IR level.
5. Add a `#[no_alloc(strict)]` opt-in that promotes the analysis from advisory-with-known-gaps to fail-closed. Adopters who want the v0.3 pitch get the strong contract; everyone else stays compiling.

---

### F-CONC-005 — `#[atomic]` and `#[isr]` blocking-call detection is single-hop only  [HIGH]

**Location:** `compiler/nucleor_s1_compiler.nr` blocking-call scanner (per probe behavior).

**Evidence:**

- `t22_atomic_blocking.nr`: `#[atomic] fn op() { let m = conc_mutex(); conc_lock(m); ... }` — no ATOMIC-001 fires. `conc_lock` is a one-line wrapper around `mutex_lock` in `concurrency.nr`.
- `t23_atomic_direct_mutex_lock.nr`: same body but calling `__nucleor_mutex_lock` via `extern fn` directly — ATOMIC-001 fires.
- `t24_atomic_channel_recv.nr`: `#[atomic] fn op() { ... return conc_recv(ch); }` — no ATOMIC-001 fires. Channel recv blocks indefinitely.
- `t21_isr_mutex.nr`: `#[isr] fn timer() { ... conc_lock(m); ... }` — no diagnostic fires. ISR implies `#[atomic]` per RFC-0008 §3.0; the implication is enforced for alloc/panic/dyn but not for blocking.

Same root cause as F-CONC-004 — substring/single-hop scan. The blocking-call detector is looking for the exact string `mutex_lock` (and probably `channel_recv`, `thread_join`, `cond_wait`, etc.) at the call site. Wrappers in `stdlib/rods/concurrency.nr` rename them and the detector loses the trail.

This is the more dangerous variant of F-CONC-004 because the blocking-detection failure couples directly to ISR safety: an ISR that locks a mutex on a real embedded target will deadlock the whole system, not just produce wrong output.

**Severity:** HIGH — `#[atomic]` and `#[isr]`'s headline guarantee ("no blocking inside") fails on the most natural way to use the stdlib (call the friendly `conc_*` wrappers). A Linux/host-side build silently runs; an embedded port crashes the chip.

**Remediation:**

1. Tag stdlib functions with explicit `may_block` annotation in audit manifests (RFC-0001 §3.5 mentions `rod_rt.audit.toml`). The blocking-detector reads the manifest. `concurrency.nr::conc_lock` → may_block ✓.
2. Or, propagate `may_block` transitively through the IR call graph from a small set of axioms (`__nucleor_mutex_lock`, `__nucleor_channel_recv`, `__nucleor_channel_send` when buffer full, `pthread_cond_wait`, `WaitForSingleObject`, `nuc_future_get`, `nuc_barrier_wait`, `pool_worker` blocks).
3. Add tests/err for the wrapper case: `err_atomic_001_blocking_via_wrapper.nr`, `err_isr_blocking_via_wrapper.nr`.

---

### F-CONC-006 — Mutex semantics differ across platforms (Windows reentrant, POSIX non-recursive)  [HIGH]

**Location:** `stdlib/runtime/nucleor_llvm_rt.c` lines 3730-3748 (Windows: `CRITICAL_SECTION`) vs lines 4017-4029 (POSIX: `pthread_mutex_init(m, NULL)` — default non-recursive).

**Evidence:**

- Windows `CRITICAL_SECTION` is **always recursive** (Microsoft documented behavior). Same thread can `EnterCriticalSection` N times and must `LeaveCriticalSection` N times.
- POSIX default `pthread_mutex_t` (no attr) is **non-recursive**. Same-thread re-lock is undefined behavior; on glibc Linux it deadlocks the thread.
- `t32_mutex_reentrant.nr` runs cleanly on Windows. Same source on Linux would self-deadlock at the second `conc_lock`.

A program that develops cleanly on Windows and ships to Linux without contention testing has hit a portability landmine the test suite has zero coverage for.

**Severity:** HIGH — silent cross-platform divergence on a primitive that adopters trust to be uniform. Nucleor's "v1.0 platform = Windows" framing makes this even more dangerous: people will write Windows-correct mutex code and assume the future Linux port "just works."

**Remediation:**

1. Pick one semantics. Recommend non-recursive default to match Rust `std::sync::Mutex` and `pthread`. Either:
   - Initialize the Windows `CRITICAL_SECTION` and use the SRWLock (`InitializeSRWLock` / `AcquireSRWLockExclusive`) which is non-recursive.
   - Or wrap the `CRITICAL_SECTION` with a `RecursionCount`-checking layer that errors on second-lock by same thread.
2. Add a separate `RecursiveMutex` type for adopters who want recursive semantics; same on both platforms.
3. Add tests/features/concurrency_mutex_reentrant_smoke.nr that probes the chosen semantics on both targets — once a Linux runner exists.

---

### F-CONC-007 — Windows channel uses 100ms polling for blocked send/recv (non-RT)  [HIGH]

**Location:** `stdlib/runtime/nucleor_llvm_rt.c` lines 3826-3866.

**Evidence:**
```c
void __nucleor_channel_send(...) {
    while (1) {
        EnterCriticalSection(&ch->lock);
        if (...buffer-has-space) { ... return; }
        LeaveCriticalSection(&ch->lock);
        WaitForSingleObject(ch->not_full, 100);   // ← 100 ms timeout, then re-poll
    }
}
```
The `not_full` event is auto-reset, so the wait IS woken correctly when consumer makes space — but the wait expires every 100 ms regardless of activity, adding a 0-100 ms latency on the blocked path. The Linux path uses `pthread_cond_wait` (correct, no timeout). Asymmetric.

For an L4-tier blocking channel this is poor latency. For RT use this is disqualifying — but channels are documented as `may_block` so RT use is already excluded; the issue is correctness symmetry across platforms and unnecessary CPU wakeup overhead.

**Severity:** HIGH — silent latency floor on Windows; cross-platform correctness/perf divergence.

**Remediation:**

1. Replace `CreateEvent` + `WaitForSingleObject` with a `CONDITION_VARIABLE` + `SleepConditionVariableCS` pair (already used by the barrier path; pattern proven). This gives Linux-equivalent wake-on-signal.
2. Or accept the polling design but document the latency floor in `concurrency_limitations()` (currently silent).

---

### F-CONC-008 — Channel default-capacity coercion silently overrides intent  [MEDIUM]

**Location:** Both Windows (line 3817) and POSIX (line 4076) `__nucleor_channel_new`: `if (ch->cap < 1) ch->cap = 16;`.

**Evidence:** `channel_new(0)` returns a channel with capacity 16. There is no zero-capacity (rendezvous) channel mode. There is no error or warning. RFC-0007 §3.4 specifies bounded queues; concurrency.nr `conc_channel(0)` silently buffers 16. An adopter expecting rendezvous semantics gets buffered semantics with a 16-element latent reordering window.

**Severity:** MEDIUM — wrong-accept of caller's intent; semantics do not match the API call.

**Remediation:** Either ship rendezvous channels (cap=0) by allocating a zero-element handshake mailbox, or reject `cap <= 0` with a runtime panic / `Result::Err`. Don't silently re-write user input.

---

### F-CONC-009 — `channel_recv` returns 0 on closed-empty AND on legitimate value=0  [MEDIUM]

**Location:** `stdlib/runtime/nucleor_llvm_rt.c` lines 3860-3863 (Windows), 4108-4111 (POSIX).

**Evidence:** When the channel is closed and empty, `__nucleor_channel_recv` returns `0`. When the channel contains the i64 value `0`, recv returns the same `0`. There is no companion `Option<i64>` / `Result` API. `t34_channel_zero_ambiguity.nr` shows `v1 == v2 == 0` despite distinct producer states.

The `concurrency_limitations()` disclosure in `concurrency.nr` line 108 documents this as design intent ("recv on a closed empty channel returns 0 instead of blocking forever"), but the design intent loses information.

**Severity:** MEDIUM — silent ambiguity. Caller patterns like `loop { let v = recv(ch); if v == 0 break; }` cannot distinguish a real zero from a closed channel and may exit early on legitimate data.

**Remediation:** Add `conc_recv_opt(ch) -> Option<i64>` returning `None` only on closed-empty. Keep the legacy `conc_recv` for backward compat but flag it as `#[deprecated]` or document the foot-gun in the API doc. The MpscQueue/SpscQueue `pop()` returning `Option<T>` is the right shape — channel should match.

---

### F-CONC-010 — `#[isr, deadline = N]` combined-attribute form bypasses ISR-002  [MEDIUM]

**Location:** Attribute parser in `compiler/nucleor_s1_compiler.nr`.

**Evidence:**
- `tests/err/err_isr_002_with_deadline.nr` uses two separate attributes (`#[isr]\n#[deadline = 10]`) — ISR-002 fires correctly.
- `audit_scratch_concurrency/t26_isr_with_deadline.nr` uses combined form `#[isr, deadline = 100us]` — file compiles silently.

Both forms are syntactically equivalent per RFC-0001 §3.1. The compiler's attribute-conflict checker only sees one of the two encodings.

**Severity:** MEDIUM — wrong-accept of combined-attribute form. A small syntactic rephrasing flips the diagnostic on/off.

**Remediation:** Normalize the attribute list before conflict-checking. After parsing, the AST should hold a `Vec<FnAttribute>` regardless of source encoding; ISR-002 then fires off the canonical list.

---

### F-CONC-011 — Pre-resolution timer values silently accepted on `#[deadline]`  [MEDIUM]

**Location:** Attribute parser, no per-target capability check.

**Evidence:** `t10_deadline_extreme.nr`:
- `#[deadline = 1ns]` accepts (Windows monotonic resolution is ~100ns at best, often 1µs).
- `#[deadline = 0us]` accepts (RT-004 fires only because heuristic loop estimate of 1us > 0us; not because zero-deadline is itself rejected).
- `#[deadline = 9999999999999s]` accepts (overflows the i64 micro-second representation when multiplied: 9.99e12 × 1e6 = 9.99e18 ≈ INT64_MAX 9.22e18; close to overflow, no overflow check).

RFC-0001 §6.2 (open question 2) recommends "reject with a per-target capability check" when the timer can't resolve the deadline. The compiler does neither resolution-check nor overflow-check.

**Severity:** MEDIUM — programs compile with deadlines they cannot honor. On a target with 1ms HW tick, `#[deadline = 100us]` is a fraud; the user has no compile-time signal.

**Remediation:**

1. Add a target-cap query: `target_caps::deadline_resolution_us()`. Reject deadlines smaller than the resolution.
2. Add overflow check on `deadline_value × time_unit_multiplier > INT64_MAX / 2`. Error with span on the duration literal.
3. Reject `deadline = 0` outright (a zero-deadline function cannot make forward progress).

---

### F-CONC-012 — Legacy `__nucleor_atomic_load` writes-on-read via CAS-with-zero  [MEDIUM]

**Location:** `nucleor_llvm_rt.c` lines 3902-3904 (Windows) and 4148-4149 (POSIX).

**Evidence:**
```c
// Windows
long long __nucleor_atomic_load(long long handle) {
    return InterlockedCompareExchange64((volatile LONG64*)(void*)handle, 0, 0);
}
// POSIX
long long __nucleor_atomic_load(long long h) { return __sync_val_compare_and_swap((long long*)(void*)h, 0, 0); }
```
This is the legacy load used by the non-typed `atomic_load_v` / `conc_atomic_get` API (`stdlib/rods/concurrency.nr` line 71). CAS-with-zero is a standard old-school "atomic load" trick when no `atomic_load` intrinsic exists — but it issues a write barrier on every read, even when the value is non-zero (the CAS still acquires the cacheline exclusive). When the value happens to be zero, the CAS swaps zero with zero (idempotent but still a write).

The typed `AtomicI64::load` correctly lowers to LLVM `load atomic` (verified by IR inspection) and does not have this issue. Only the legacy raw-handle path is affected.

**Severity:** MEDIUM — performance and cache-coherence behavior under contention is dramatically worse than a real atomic load (every reader invalidates other CPUs' lines on every read). On a 1 kHz control loop with 8 readers this is observable.

**Remediation:** Replace with `__atomic_load_n(p, __ATOMIC_SEQ_CST)` (clang/gcc) or `_InterlockedExchangeAdd64(p, 0)` is similarly problematic; better: use `MemoryBarrier()` plus a volatile read on Windows, or upgrade the legacy path to `_InterlockedOr64(p, 0)` which is no-op-write-on-true-zero but still touches the line; the right answer is the C11 `atomic_load(_Atomic long long *)`. Or just deprecate `atomic_load_v` and route everyone to the typed `AtomicI64::load`.

---

### F-CONC-013 — SpscQueue `Vec::set` on Option<T> is not torn-write-safe for non-i64 T  [MEDIUM]

**Location:** `stdlib/rods/spsc_queue.nr` lines 43, 56; `stdlib/rods/mpsc_queue.nr` lines 67, 86.

**Evidence:** Both queues store `Vec<Option<T>>` and use `q.buffer.set(slot, Some(val))` on the producer side and `q.buffer.get(slot)` on the consumer side. The runtime `__nucleor_vec_set` (line 2604) is a plain non-atomic store.

For `Option<i64>` on x86_64, the layout is likely 16 bytes (8-byte tag + 8-byte payload), and a 16-byte store is NOT atomic at the hardware level on x86_64 without `lock cmpxchg16b` or `movdqa` to an aligned buffer (which Vec doesn't guarantee). Producer/consumer pair can observe a torn `Some` (tag=Some, payload=stale) or a torn `None` (tag=None, payload=fresh).

The reference RFC-0007 design (§3.4) is "Vyukov bounded MPMC queue" which uses sequence-number publication on each slot — the MpscQueue in this codebase does carry a `sequence: Vec<AtomicI64>` (line 16) and `mpsc_pop_shared` checks the sequence before reading, so the MPSC is mostly safe. But `SpscQueue` has no per-slot sequence and relies on head/tail counters alone — the slot value is read after the consumer has confirmed `head < tail`, but the producer may have set the slot before publishing tail, and the consumer only `Acquire`-loads tail. Still hazardous if `Option<T>` size exceeds the architecture's atomic-store width.

For `T = i64`, the slot is `Option<i64>` ≈ 16 bytes and **may tear**. For `T = i32` similar. For larger composite T, definitely tears.

**Severity:** MEDIUM — only manifests under real producer/consumer contention with non-trivial T. Not exercised by existing tests (all tests are single-thread or use trivial T). On x86 with strong store ordering and aligned slot writes the practical risk is low; on weakly-ordered ARM/RISC-V the risk is real.

**Remediation:**

1. Document the T-size constraint in `spsc_queue.nr` head comment ("T must fit in a single machine word and the slot store is non-atomic"). Verify with a static-assert at instantiation.
2. Or have producer write the slot *before* `atomic_store(&q.tail, ..., Release)` (it does: line 43 → line 44). Consumer must `Acquire` the tail (it does: line 50). The release-acquire pair provides happens-before for the slot store, so the slot is **visible** by the time the consumer reads. ✓
3. The remaining hazard is the SLOT itself being written non-atomically: if the producer is mid-write when an interrupt suspends and the consumer runs, the consumer sees `Some` tag but stale payload. This is a real bug for `Option<T>` larger than word size. Fix: add a per-slot `AtomicI64` sequence to the SPSC too, mirroring MPSC's design.

---

### F-CONC-014 — `concurrency.nr conc_map` is sequential, not parallel (documented but tests pass anyway)  [NOTE]

**Location:** `stdlib/rods/concurrency.nr` lines 90-100.

**Evidence:** Per the doc-comment + `concurrency_limitations()`, `conc_map` runs sequentially in the caller thread. The function name and the rod's "structured concurrency with safety guardrails" header strongly suggest parallel execution. The disclosure is buried in a `concurrency_limitations()` string that adopters must explicitly call to read.

**Severity:** NOTE — documented misnomer. Phase 2 promises real parallel via `nuc_threadpool_map`. Until then, the `conc_map_is_parallel()` returns 0 — a programmable check at least exists.

**Remediation:**

1. Rename to `conc_map_seq` or `conc_map_serial` to match behavior.
2. Or actually parallelize it now via the existing `nuc_threadpool_map` (which is already wired and used by `thread_pool_map`).

---

### F-CONC-015 — `build-strict` panics on `Vec::with_capacity` source pattern  [MEDIUM]

**Location:** `nucleor_tools` strict checker (path unknown — emitted by `bin/nucleor_tools.exe`).

**Evidence:** `audit_scratch_concurrency/t05_no_alloc_violation.nr` (`Vec::with_capacity(1024)` body) compiled OK with `build` but `build-strict` emitted:
```
ERROR: unhandled expr kind 12
PANIC: nucleor_tools: unhandled expr kind 12
```
Strict mode is supposed to be the *more thorough* checker; it instead aborts on a syntactic shape the fast path accepts. Adopters who follow the docs ("use build-strict for full checks") cannot get past trivial real-time code.

**Severity:** MEDIUM — strict mode is unusable for real-time code that uses pre-allocated Vec patterns.

**Remediation:**

1. Add the missing AST handler for `expr_kind 12` (likely a method-call-with-type-args / generic-method-call shape).
2. Until fixed, suppress the panic: emit a `STRICT-???` warning and fall back to the fast path. Don't abort the whole build.

---

### F-CONC-016 — Verify suite has no contention test, no double-free test, no platform-divergence test  [HIGH]

**Location:** `tests/features/`, `tests/rods/atomic.nr`, `tests/rods/thread_smoke.nr`, `tests/err/err_atomic_*`.

**Evidence:** Reviewed every test file under `tests/` whose name contains thread / conc / atomic / spsc / mpsc / mutex / channel / barrier / rt / deadline / isr. Every functional test runs single-threaded or uses single-element bursts. Every error test exercises one statically-decidable diagnostic. None of the audit findings F-CONC-001 through F-CONC-014 would be caught by the existing verify suite.

The probe-2 mandate (`PARALLEL_AGENT_PROBE_MANDATE.md`) appears to focus on math/numeric findings; concurrency is sparsely covered.

**Severity:** HIGH (meta-finding) — verify is missing the entire risk class. Verify-clean does not imply concurrency-correct.

**Remediation:** Add at minimum:

- `tests/features/concurrency_atomic_uaf_smoke.nr` (must abort, not crash) — pin the F-CONC-001 hazard.
- `tests/features/concurrency_future_double_get_smoke.nr` — pin F-CONC-002.
- `tests/features/concurrency_deadline_midexec_trap_smoke.nr` — once F-CONC-003 fix lands.
- `tests/err/err_no_alloc_with_capacity.nr`, `err_no_alloc_box_new.nr`, `err_no_panic_oob_get.nr`, `err_atomic_001_blocking_via_wrapper.nr`, `err_isr_blocking_via_wrapper.nr` — pin F-CONC-004 / F-CONC-005.
- `tests/features/concurrency_atomic_contention_stress.nr` — 8 threads × 100k atomic fetch_add against expected sum, asserts no lost updates. (Already verified manually in t16 — promote to suite.)
- `tests/features/concurrency_mutex_reentrant_semantics.nr` — pin the chosen semantics from F-CONC-006.

---

## Summary table

| ID | Severity | One-line |
|---|---|---|
| F-CONC-001 | CRITICAL | Atomic raw-handle UAF / forge / double-drop crashes process |
| F-CONC-002 | CRITICAL | thread_future_get double-call crashes via heap UAF |
| F-CONC-003 | HIGH | `#[deadline]` is post-hoc detector, not enforcer (38000% overrun observed) |
| F-CONC-004 | HIGH | `#[no_alloc]` / `#[no_panic]` substring scan misses RFC-listed canonical patterns |
| F-CONC-005 | HIGH | `#[atomic]` / `#[isr]` blocking-call detection is single-hop only |
| F-CONC-006 | HIGH | Mutex semantics divergence: Windows recursive, POSIX non-recursive |
| F-CONC-007 | HIGH | Windows channel uses 100ms polling on blocked send/recv |
| F-CONC-008 | MEDIUM | Channel cap=0 silently coerced to 16 |
| F-CONC-009 | MEDIUM | channel_recv returns 0 ambiguously (closed-empty == real zero) |
| F-CONC-010 | MEDIUM | ISR-002 misses `#[isr, deadline=N]` combined-attribute form |
| F-CONC-011 | MEDIUM | Sub-resolution / zero / overflow `#[deadline]` values silently accepted |
| F-CONC-012 | MEDIUM | Legacy `atomic_load_v` writes-on-read via CAS-with-zero |
| F-CONC-013 | MEDIUM | SpscQueue slot store is non-atomic for Option<T> larger than word size |
| F-CONC-014 | NOTE | `conc_map` is sequential despite name (documented) |
| F-CONC-015 | MEDIUM | `build-strict` panics on `Vec::with_capacity` source pattern |
| F-CONC-016 | HIGH | Verify suite lacks contention / UAF / platform-divergence tests |

## Top remediation priorities (in order)

1. **F-CONC-001 / F-CONC-002**: ship a handle-table layer (single fix subsumes both). All concurrency primitives currently use raw `i64 = pointer`; this is the root soundness gap of the whole layer.
2. **F-CONC-003**: real timer-based deadline trap. Without this, RFC-0001 §3.2.4 is misrepresented in the marketing.
3. **F-CONC-004 / F-CONC-005**: move RT-attribute enforcement off substring matching onto the IR call graph. Fixes seven separate gaps (Vec::with_capacity, Box::new, OOB, FFI, fn-ptr, depth-9, single-hop wrapper).
4. **F-CONC-006**: pick mutex semantics. Recommend non-recursive (match Rust/POSIX). Add cross-platform parity test.
5. **F-CONC-016**: backfill verify with the 6 tests listed.

Lower-priority MEDIUM items (007-015) are tractable individually and do not block the v1.0 launch quality bar so much as document the limits.
