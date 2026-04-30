# RFC-0007 — `#[atomic]` and Lock-Free Data Structures

| Field | Value |
|---|---|
| **Number** | 0007 |
| **Title** | `#[atomic]` attribute, `Atomic<T>` types, and lock-free primitives |
| **Status** | Partial (audited v0.4.191). `stdlib/rods/atomic.nr` ships an `AtomicI64` surface with sequentially-consistent ordering, backed by Win32 `Interlocked*` (MSVC) and C11 stdatomic (POSIX). API: `atomic_new(initial) → handle`, `atomic_load_v(h)`, `atomic_store_v(h, v)`, `atomic_add(h, v)`, `atomic_sub`, `atomic_and_v`, `atomic_or_v`, `atomic_xor_v`, `atomic_cas` (compare-and-swap), `atomic_drop(h)`. The 64-bit lock-free counter / CAS spinlock / atomic flag use cases are all covered. **Deferred to v0.5.0+ targeted ship:** the `#[atomic]` attribute (compile-time enforcement of "this fn only uses atomic ops"), `Atomic<T>` generic surface for non-i64 widths, Relaxed/Acquire/Release ordering variants, and the SPSC/MPMC lock-free queues built on top. |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.5.0 ("Production Robotics") |
| **Depends on** | RFC-0001, RFC-0002 |

---

## 1. Summary

Add atomic primitives and a `#[atomic]` attribute that marks a
function as lock-free (no blocking, no allocation, no panics — like
RT attributes plus "no waiting").

```nucleor
struct Counter {
    value: Atomic<i64>,
}

#[atomic]
fn increment(c: &Counter) -> i64 {
    c.value.fetch_add(1, Ordering::SeqCst)
}

let queue: SpscQueue<Reading, 256> = SpscQueue::new();
let producer_thread = spawn(move || {
    queue.try_push(reading);   // lock-free push, returns Result
});
```

Ships:
- `Atomic<T>` for `i8 … i64`, `u8 … u64`, `*mut T`, `bool`
- `Ordering` enum (`Relaxed`, `Acquire`, `Release`, `AcqRel`, `SeqCst`)
- `Mutex<T>` (blocking, NOT atomic — for non-RT code)
- `SpscQueue<T, N>` — single-producer single-consumer lock-free ring
- `MpmcQueue<T, N>` — multi-producer multi-consumer lock-free ring
- `RwLock<T>` (blocking — for non-RT code)
- `#[atomic]` attribute that forbids any blocking/allocating call

The `#[atomic]` attribute is the **inter-thread** equivalent of
RFC-0001's `#[no_alloc, no_panic, deadline]`. Together they make
Nucleor real-time-safe both within and across threads.

---

## 2. Motivation

Real-time + multi-thread = lock-free. Mutexes can priority-invert,
allocators can fragment, panics can cascade. The world's hard-real-
time codebases use lock-free data structures and never block.

Today Nucleor has `mutex.nr` rod — fine for L4 but unusable at L1.
This RFC adds the lock-free tier.

Prior art: Rust `std::sync::atomic` + `crossbeam` + `lockfree`
crates. C++ `std::atomic`. Most languages have these as libraries,
not language features. **`#[atomic]` as a compiler-enforced attribute
is novel.**

---

## 3. Design

### 3.1 `Atomic<T>` types

```nucleor
pub struct Atomic<T> { ... }   // built-in type, mapped to LLVM atomics

impl Atomic<i64> {
    pub const fn new(v: i64) -> Self;
    pub fn load(&self, ord: Ordering) -> i64;
    pub fn store(&self, v: i64, ord: Ordering);
    pub fn swap(&self, v: i64, ord: Ordering) -> i64;
    pub fn compare_exchange(&self, current: i64, new: i64, succ: Ordering, fail: Ordering)
        -> Result<i64, i64>;
    pub fn fetch_add(&self, v: i64, ord: Ordering) -> i64;
    pub fn fetch_sub(&self, v: i64, ord: Ordering) -> i64;
    pub fn fetch_and(&self, v: i64, ord: Ordering) -> i64;
    pub fn fetch_or(&self,  v: i64, ord: Ordering) -> i64;
    pub fn fetch_xor(&self, v: i64, ord: Ordering) -> i64;
    pub fn fetch_max(&self, v: i64, ord: Ordering) -> i64;
    pub fn fetch_min(&self, v: i64, ord: Ordering) -> i64;
}
```

Same for `Atomic<i32>`, `Atomic<u64>`, `Atomic<bool>`,
`Atomic<*mut T>`, etc. Generated via macro.

### 3.2 `Ordering` enum

```nucleor
pub enum Ordering {
    Relaxed,    // no ordering, only atomicity
    Acquire,    // load-acquire
    Release,    // store-release
    AcqRel,     // both
    SeqCst,     // sequentially consistent (default if unsure)
}
```

C++/Rust memory model. Standard.

### 3.3 `#[atomic]` attribute

```nucleor
#[atomic]
fn lock_free_op(state: &Counter) -> i64 { ... }
```

Compiler enforces:
- No allocation (any allocator)
- No panic (RFC-0001 conservative analysis)
- No dynamic dispatch (`#[no_dyn]`)
- **No call to `Mutex::lock`, `RwLock::read`, `RwLock::write`**
- **No call to `std::thread::sleep`, `Channel::recv` (blocking)**
- **No syscall** (transitively — through stdlib audit manifest)

Implies `#[no_alloc, no_panic, no_dyn]` plus the new "no blocking"
constraint.

### 3.4 Lock-free queues

**`SpscQueue<T, N>`** — single-producer single-consumer ring buffer.
Bounded capacity `N`. Methods: `try_push(T) -> Result<(), T>`,
`try_pop() -> Option<T>`. Wait-free.

**`MpmcQueue<T, N>`** — multi-producer multi-consumer.
Implementation: Vyukov bounded MPMC queue (well-known design,
~150 LOC C). Lock-free, not wait-free.

Both are `#[atomic]`-callable.

### 3.5 Mutex / RwLock — for non-RT code

Standard blocking primitives. Marked `may_block` in audit manifest;
`#[atomic]` and `#[deadline]` callers cannot use them.

### 3.6 Composition with allocators (RFC-0002)

`Atomic<T>` is fixed-size (no allocation). `SpscQueue<T, N>` and
`MpmcQueue<T, N>` are allocated once at construction; `try_push`
copies the value into pre-allocated storage. Both safe under
`#[no_alloc(global)]`.

### 3.7 Diagnostics

| Code | Meaning |
|---|---|
| ATOMIC-001 | Blocking call inside `#[atomic]` function |
| ATOMIC-002 | Allocating call inside `#[atomic]` function (also RT-001 fires) |
| ATOMIC-003 | Use of `Cell<T>`/`RefCell<T>` in `#[atomic]` (interior mutability incompatible with atomic semantics) |
| ATOMIC-004 | Mismatched orderings in `compare_exchange` (Acquire/Release combination invalid) |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Parser | `#[atomic]` attribute, `Atomic<T>` type | ~100 |
| Type checker | "no blocking" rule | ~250 |
| Codegen | Map `Atomic<T>` ops to LLVM atomic intrinsics | ~200 |
| Runtime | `runtime/spsc_queue_rt.c`, `runtime/mpmc_queue_rt.c` | ~350 |
| Stdlib | `stdlib/rods/atomic.nr`, `spsc.nr`, `mpmc.nr` | ~400 |
| Diagnostics | ATOMIC-001…004 | ~150 |
| **Total** | | **~1450** |

---

## 5. Alternatives considered

- **No language attribute, just types** — loses compile-time
  enforcement for "function is lock-free." Rejected.
- **Software-transactional-memory** — out of scope.
- **Hazard pointers / RCU** — too specialized for v0.5; can be
  community rod.
- **Lock elision via HLE/RTM** — Intel-specific; defer.

## 6. Open questions

1. Default ordering when omitted? Recommend `SeqCst` (Rust does this).
2. `Atomic<f64>`? CAS-loop emulated. Recommend ship; useful for
   accumulators.
3. Memory-model proof obligation for SeqCst on weak architectures
   (ARM, RISC-V)? LLVM handles; document target-specific costs.
4. Wait-free MPMC instead of just lock-free? Vastly more complex; defer.
5. Should `#[atomic]` imply `#[no_alloc(global, pool, tlsf)]`
   (allow only Arena)? Recommend no — Pool and TLSF are O(1).

## 7. Definition of done

- [ ] `Atomic<T>` for all primitive int/uint/bool, plus `*mut T`
- [ ] `Ordering` enum with all 5 variants
- [ ] `#[atomic]` attribute parses, enforces
- [ ] `SpscQueue` and `MpmcQueue` ship and pass stress tests
- [ ] CHANGELOG documents lock-free primitives

## 8. Future extensions

- Wait-free MPMC (Yang/Mellor-Crummey)
- Hazard pointers / epoch-based reclamation
- RCU-style read-mostly structures
- `Atomic<UserStruct>` via `Atomic<u128>` packing (research)

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] Compatible with v0.5 schedule
- [ ] LOC budget ~1450 fits
- [ ] Pitch survives ("real-time across threads, not just within")
