# RFC-0002 — Allocator Types

| Field | Value |
|---|---|
| **Number** | 0002 |
| **Title** | Allocator Types — `Box<T, A: Allocator>`, `Vec<T, A: Allocator>`, plus Arena / Pool / TLSF |
| **Status** | Partial (audited v0.4.188). Basic `Box<T>` (sugar for `Box<T, Global>`) + `Box::new(value)` ship + lower correctly + free on drop. **Deferred to v0.5+:** parameterized allocator types `Box<T, Arena>` / `Box<T, Pool>` / `Box<T, TLSF>`, the `Arena` / `Pool` / `TLSF` types themselves (their `::new(...)` associated fns aren't recognized — currently fails with "unsupported associated-fn call"), and the parameterized `#[no_alloc(global)]` / `#[no_alloc(global, pool)]` form. The non-parameterized `#[no_alloc]` ships per RFC-0001. |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.3.0 ("Robotics Foundation") |
| **Depends on** | RFC-0001 (Real-Time Function Attributes) — soft dependency for `#[no_alloc(global)]` granular form |

---

## 1. Summary

Make the allocator a **type parameter** on every owning container.
Today every `Box<T>` and `Vec<T>` implicitly uses the global heap
(`malloc`/`free`). Under this RFC:

```nucleor
let scratch: Arena = Arena::new(1 << 16);

let a: Box<Sensor, Arena>     = scratch.alloc(Sensor::new());
let b: Box<Reading, Pool>     = sensor_pool.alloc(Reading::new());
let c: Box<Plan, TLSF>        = rt_heap.alloc(Plan::default());
let d: Box<Config, Global>    = Box::new(Config::default());   // explicit
let e: Box<Telemetry>         = Box::new(Telemetry::default()); // sugar for <T, Global>
```

Each `Box`/`Vec` carries the allocator it came from in its type, and
the allocator's `Drop` rule determines how the storage is freed.
**`#[no_alloc]` from RFC-0001 becomes parameterized**:

```nucleor
#[no_alloc(global)]                 // reject Global only — arenas/pools/tlsf OK
fn fast_path(arena: &Arena) { … }

#[no_alloc(global, pool)]           // reject Global + Pool — arena/tlsf only
fn rt_path(arena: &Arena) { … }

#[no_alloc]                         // reject all four — pre-allocated only
fn isr() { … }
```

Three new allocator types ship in v0.3:

| Allocator | File | Use case |
|---|---|---|
| `Arena` | `stdlib/rods/arena.nr` (exists, expand) | Bump allocator, drop-arena to free everything |
| `Pool<T>` | `stdlib/rods/pool.nr` (new) | Fixed-size object pool, O(1) alloc/free, no fragmentation |
| `TLSF` | `stdlib/rods/tlsf.nr` (new) | Two-Level Segregated Fit, deterministic worst case |
| `Global` | implicit (existing `malloc` path) | Default for non-RT code |

**Memory safety is preserved across all four.** Same ownership rules
apply; the allocator is a phantom type the borrow checker threads
through.

---

## 2. Motivation

### 2.1 What's wrong today

Every Nucleor allocation goes through the global heap. This is fine
for normal code but catastrophic for the L1/L2 robotics tier:

- The global allocator can take milliseconds in the worst case
  (free-list traversal, OS page fault, fragmentation cleanup). A
  1 kHz control loop has 1 ms total — a single `malloc` can blow it.
- Fragmentation grows over time. A robot that runs for weeks
  experiences allocator behavior the developer never observed in test.
- Real-time scheduling requires upper-bounded allocator latency. The
  global heap doesn't provide this; specialized allocators do.
- Embedded targets often **have no global allocator at all** (no
  `malloc` in `no_std` Rust without `alloc` crate; no `malloc` at all
  in deeply embedded firmware).

### 2.2 What other languages do

| Language | Approach | Limitation |
|---|---|---|
| **C** | Hand-rolled. `arena_alloc` / `pool_alloc` / `tlsf_alloc` libraries. No type tracking. | Easy to mix arenas; no compile-time check |
| **C++** | `std::pmr::polymorphic_allocator`, `std::allocator_traits`. Verbose, opt-in per container. | Type tracking exists but most code ignores it |
| **Rust** | `Box<T, A: Allocator>` on nightly (`#![feature(allocator_api)]`). Stable but unstable. | Not stable yet (since 2018); ecosystem hasn't adopted |
| **Zig** | `Allocator` parameter explicit in every function that allocates. | Best-in-class. Verbose. |
| **Ada** | `Storage_Pool` aspect on access types. Pool-per-type, statically scoped. | Gold standard for safety-critical. Awkward for general code. |

**Nucleor's opportunity:** ship Rust's `Box<T, A: Allocator>` as a
stable feature with three first-party allocators (Arena, Pool, TLSF),
type-tracked through the borrow checker, and integrated with
`#[no_alloc(...)]` from RFC-0001. Cleaner than C++, more ergonomic
than Zig, more general than Ada.

### 2.3 What we want

Concretely, after this RFC:

1. Every `Box<T>` and `Vec<T>` carries an allocator type parameter.
   Default is `Global` for backward compatibility.
2. Three allocator types ship in stdlib: `Arena`, `Pool<T>`, `TLSF`.
3. The borrow checker enforces that a `Box<T, A>` cannot outlive its
   `A`. (An arena-allocated value cannot escape the arena.)
4. `#[no_alloc(...)]` accepts an allocator allow-list.
5. Generic functions parameterize over allocator (`fn f<A: Allocator>(x:
   Box<T, A>)`), enabling allocator-agnostic libraries.

---

## 3. Design

### 3.1 The `Allocator` trait

```nucleor
trait Allocator {
    /// Allocate enough storage for `T` and return a pointer.
    /// Returns `None` if allocation fails (out of memory, fragmentation,
    /// pool exhaustion, etc.).
    fn alloc<T>(&self, init: T) -> Option<Box<T, Self>>;

    /// Deallocate. Called by `Box::drop`.
    fn dealloc<T>(&self, ptr: *mut T);

    /// Worst-case allocation latency in nanoseconds, statically known
    /// for the allocator type. Used by `#[deadline]` analysis.
    const MAX_ALLOC_NS: u64;

    /// Whether this allocator may panic on alloc.
    const MAY_PANIC: bool;
}
```

Stdlib implementors:

| Allocator | `MAX_ALLOC_NS` | `MAY_PANIC` |
|---|---|---|
| `Arena` | 50 ns (bump pointer + alignment) | `false` (returns `None` on overflow) |
| `Pool<T>` | 30 ns (free-list pop) | `false` |
| `TLSF` | 200 ns (two-level lookup, bounded) | `false` |
| `Global` | unbounded (typically 100 ns – 1 ms) | `true` (Linux OOM-killer; Windows `__chkstk`) |

### 3.2 `Box<T, A: Allocator = Global>`

The default allocator is `Global` — existing code continues to work
unmodified. To use a non-global allocator, the user names it:

```nucleor
let arena = Arena::with_capacity(1 << 16);
let p: Box<Pose, Arena> = arena.alloc(Pose::default());
// or
let p = arena.alloc(Pose::default());  // type inferred from arena
```

`Box<T, A>` has the same ownership semantics as today's `Box<T>`:
exactly one owner, dropped when it goes out of scope. The allocator
type just affects *how* `Drop` works.

**Key constraint:** `Box<T, A>` cannot outlive `A`. The borrow checker
enforces this via a phantom lifetime tied to the allocator handle.

```nucleor
fn bad() -> Box<Pose, Arena> {
    let arena = Arena::with_capacity(1024);
    let p = arena.alloc(Pose::default());
    return p;  // ERROR: Box<Pose, Arena> outlives the Arena it was allocated from
}
```

Diagnostic:
```
error[ALLOC-001]: allocated value escapes its allocator
  --> src/control.nr:3:12
   |
1  | fn bad() -> Box<Pose, Arena> {
2  |     let arena = Arena::with_capacity(1024);
   |         ----- arena dropped at end of function
3  |     let p = arena.alloc(Pose::default());
   |             ----------- `p` borrows from `arena`
4  |     return p;
   |            ^ returning value that outlives the arena
   |
   = help: take `&Arena` as a parameter so the caller owns the arena lifetime
   = help: or copy the value into a `Global`-allocated `Box` before returning
```

### 3.3 `Vec<T, A: Allocator = Global>`

Same shape:

```nucleor
let mut v: Vec<f64, Arena> = Vec::with_capacity_in(1024, &arena);
v.push(0.0);  // OK if v has spare capacity
```

`Vec::push` becomes interesting under allocator types:

| Method | Behavior |
|---|---|
| `Vec::with_capacity_in(n, alloc)` | Pre-allocates `n` slots. Required for `#[no_alloc]` use. |
| `Vec::push(x)` | Pushes if there's capacity; allocates from `A` to grow if not. |
| `Vec::push_within_capacity(x)` | Returns `Result<(), T>` — never allocates. Required for `#[no_alloc]` users who don't trust the grow. |

The compiler tracks per-`Vec` whether it's currently at capacity and
flags `Vec::push` as `may_alloc` if the analysis can't prove capacity
is available. Users in `#[no_alloc]` functions must use
`push_within_capacity` or pre-size the vec.

### 3.4 `Arena` allocator

```nucleor
struct Arena {
    storage: *mut u8,
    capacity: usize,
    offset: Cell<usize>,    // bump pointer
}

impl Arena {
    fn with_capacity(bytes: usize) -> Arena { … }
    fn alloc<T>(&self, init: T) -> Option<Box<T, Arena>> { … }
    fn reset(&mut self) { self.offset.set(0); }   // free everything
}

impl Drop for Arena {
    fn drop(&mut self) { libc::free(self.storage); }
}
```

**Properties:**
- O(1) allocation (bump pointer + alignment).
- O(N) free at arena drop, but typically called once per control-loop
  iteration, amortizing to O(1) per allocation.
- No fragmentation (everything is bump-allocated).
- Zero per-allocation overhead beyond alignment padding.
- **Cannot deallocate individual values** — `Box<T, Arena>::drop`
  runs the value's destructor but the storage stays in the arena
  until `arena.reset()` or `arena.drop()`.

### 3.5 `Pool<T>` allocator

```nucleor
struct Pool<T> {
    storage: Vec<MaybeUninit<T>>,
    free_list: Cell<*mut Slot<T>>,
}

impl<T> Pool<T> {
    fn with_capacity(n: usize) -> Pool<T> { … }
    fn alloc(&self, init: T) -> Option<Box<T, Pool<T>>> { … }
}

// Pool::dealloc pushes the slot back onto the free list.
```

**Properties:**
- O(1) alloc (pop free list head).
- O(1) free (push onto free list head).
- No fragmentation (fixed-size slots).
- Pool exhaustion returns `None` rather than panicking.
- One pool per type; mixed-type pools require a separate generalized
  pool (out of scope, can be community rod).

**Use case:** message queues with bounded backlogs; sensor reading
buffers; planner candidate lists.

### 3.6 `TLSF` allocator

```nucleor
struct TLSF {
    storage: *mut u8,
    capacity: usize,
    fl_bitmap: u64,                  // First-Level free-list bitmap
    sl_bitmap: [u32; 64],            // Second-Level bitmaps
    free_lists: [[*mut Block; 32]; 64],
}
```

**Properties:**
- O(1) alloc and free with bounded worst case (~200 ns measured on
  Cortex-M4F at 168 MHz).
- Bounded fragmentation (proven to be < 25% of capacity in steady
  state).
- Variable-size allocation (unlike `Pool<T>` which is fixed-size).
- Deterministic — same allocation pattern always takes the same time.

**Use case:** the catch-all RT allocator when arenas don't fit (long-
lived heterogeneous data) and pools don't fit (variable-size data).

Implementation: ~600 LOC C in `tlsf_rt.c`, based on the original
Masmano/Ripoll/Real algorithm (MIT-licensed reference impl exists).

### 3.7 Composition with `#[no_alloc]`

RFC-0001's `#[no_alloc]` becomes **parameterized** by allocator type:

```nucleor
#[no_alloc]                          // reject ALL allocators (incl. Arena/Pool/TLSF)
#[no_alloc(global)]                  // reject Global only
#[no_alloc(global, pool)]            // reject Global and Pool
#[no_alloc(global, pool, tlsf)]      // arena only
```

The grammar for the attribute:

```
no_alloc_attr := '#[no_alloc' ('(' alloc_list ')')? ']'
alloc_list    := alloc_name (',' alloc_name)*
alloc_name    := 'global' | 'arena' | 'pool' | 'tlsf' | <user-defined>
```

The default `#[no_alloc]` (no parens) is **the strictest** — useful
for ISRs and pre-allocated-only code. Most RT code wants
`#[no_alloc(global)]` (allows arena/pool/tlsf).

The compiler enforces by walking the body, finding every allocation,
inspecting the allocator's type, and rejecting if the allocator is in
the forbidden list.

### 3.8 Inference — caller-provides-arena pattern

A common pattern: a function takes `&Arena` as a parameter and
allocates into it.

```nucleor
#[no_alloc(global)]
fn build_plan(arena: &Arena, sensors: &[Reading]) -> Box<Plan, Arena> {
    let p = arena.alloc(Plan::default());
    for s in sensors {
        p.add_sensor(s);
    }
    return p;
}
```

The compiler infers:
- `arena` is `Arena`-typed.
- `arena.alloc(...)` returns `Box<T, Arena>`.
- The function returns a `Box<T, Arena>` whose lifetime is bounded by
  the input `&Arena` borrow. The return type *implicitly* borrows
  `'a` from the input arena.

Lifetime annotation can be made explicit:

```nucleor
fn build_plan<'a>(arena: &'a Arena, sensors: &[Reading]) -> Box<Plan, &'a Arena>
```

But the `'a` on `Box<Plan, &'a Arena>` is awkward — Rust's
allocator API papers over this with `&'a A` impl. We'll do the same.

### 3.9 Generic functions over allocators

A library that wants to be allocator-agnostic:

```nucleor
fn merge<T: Ord, A: Allocator>(a: Vec<T, A>, b: Vec<T, A>, alloc: &A) -> Vec<T, A> {
    let mut out: Vec<T, A> = Vec::with_capacity_in(a.len() + b.len(), alloc);
    // ...
    return out;
}
```

This compiles to a separate monomorphization per allocator type used.
Standard story; same as Rust generics.

### 3.10 Deserialization and tainted allocators

RFC-0001 marks DDS-deserialized messages as `tainted<T>`. Under this
RFC, deserialized messages also carry their allocator:

```nucleor
fn handle_msg(arena: &Arena, raw: &[u8]) -> Result<Pose, ParseError> {
    let msg: tainted<Pose, Arena> = parse_into(arena, raw)?;
    let validated: Pose = msg.validate()?;
    return Ok(validated);
}
```

This composes cleanly: the message lives in the arena, gets validated
(stripping the `tainted<>`), and is consumed before the arena is
reset. No global heap touched.

---

## 4. Implementation

### 4.1 Compiler changes

| Component | Change | LOC est. |
|---|---|---|
| Lexer/Parser | Allocator type parameter syntax `Box<T, A>` | ~80 |
| Type checker | `Allocator` trait + dispatch + lifetime tracking | ~600 |
| Borrow checker | Phantom-lifetime rule "Box can't outlive Allocator" | ~250 |
| `#[no_alloc(...)]` parsing + enforcement | Extend RFC-0001 enforcement | ~150 |
| Codegen | Allocator-typed `Drop` dispatch | ~200 |
| Diagnostics | ALLOC-001…ALLOC-006 | ~250 |
| **Total** | | **~1530** |

### 4.2 Runtime changes

| Component | Change | LOC est. |
|---|---|---|
| `runtime/arena_rt.c` | Expand existing arena impl with reset, capacity-check, alignment | ~150 |
| `runtime/pool_rt.c` | New pool allocator | ~250 |
| `runtime/tlsf_rt.c` | New TLSF allocator (port reference impl) | ~600 |
| `runtime/box_rt.c` | Allocator-aware Box destructor dispatch | ~80 |
| **Total** | | **~1080** |

### 4.3 Stdlib changes

| Rod | Change |
|---|---|
| `stdlib/rods/arena.nr` | Promote existing arena to first-class allocator with `Allocator` impl |
| `stdlib/rods/pool.nr` | NEW |
| `stdlib/rods/tlsf.nr` | NEW |
| `stdlib/rods/box.nr` | Add allocator type parameter |
| `stdlib/rods/vec.nr` | Add `with_capacity_in`, `push_within_capacity` |
| `stdlib/rods/string.nr` (per v0.2 T1.3) | Allocator-parameterized |
| `stdlib/rods/hashmap.nr` | Allocator-parameterized |

### 4.4 Test plan

- **Unit tests** (`tests/attrs/no_alloc_arena_ok.nr`,
  `no_alloc_pool_ok.nr`, `no_alloc_tlsf_ok.nr`): each demonstrates
  a `#[no_alloc(global)]` function using its allocator.
- **Negative tests** (`tests/err/`):
  - `err_alloc_escape_arena.nr` — Box<T, Arena> returned from fn
    where Arena is local
  - `err_alloc_global_in_no_alloc.nr`
  - `err_alloc_pool_in_no_alloc_pool.nr`
- **Integration test** (`tests/features/rt_message_loop.nr`): a 1 ms
  loop that allocates a `Box<Msg, Pool>`, processes, drops, never
  touches global heap.
- **Benchmark** (`tests/bench/alloc_latency.nr`): measure
  `MAX_ALLOC_NS` claims for each allocator across 1M iterations.

### 4.5 Migration

`Box<T>` continues to mean `Box<T, Global>`. Existing code is
unchanged. Users opt into allocator-typed `Box<T, A>` when they want
the safety property.

The one breaking change: stdlib functions that take/return `Box<T>`
will be re-typed as `Box<T, A: Allocator = Global>` to preserve
default-Global behavior while enabling generic-over-allocator use.
This is source-compatible (defaulted type parameter) but ABI-affecting
(monomorphizations differ).

---

## 5. Alternatives considered

### 5.1 Untyped allocators (C-style)

Pass an `Allocator*` runtime value through every function. No
compile-time tracking. Simple but no safety property — caller can
mismatch allocators and the borrow checker can't help.

**Rejected:** loses the entire point. We want the *type system* to
enforce the constraint, not vibes.

### 5.2 Single global RT allocator

Replace the global allocator with a TLSF-backed one, project-wide.
No per-type tracking needed; everything is RT-safe by construction.

**Rejected:**
- Wastes the L3+ tier (general-purpose code doesn't need TLSF
  overhead).
- Cannot serve the "this function is RT, that one isn't" model.
- Forces TLSF's worst-case overhead on every allocation in the
  program.

### 5.3 Region-based memory management (Cyclone-style)

Lifetime-scoped memory regions inferred by the compiler. More
expressive than allocators but very heavy as a type-system feature.

**Rejected for now:** can be revisited in v0.7+. For v0.3 the
allocator-as-type-parameter model is simpler and Rust has shown it
works at scale.

### 5.4 `#[in_arena]` scoped attribute instead of allocator type

`fn f() #[in_arena = my_arena] { let x = Box::new(...); }` would
implicitly route `Box::new` calls to `my_arena`. Less verbose at the
call site.

**Rejected:** opaque. The reader of `Box::new(x)` can't see which
allocator is in play. Type parameters make it explicit.

---

## 6. Open questions

1. **Default-Global change in v0.3 vs v1.0.**
   `Box<T>` defaulting to `Box<T, Global>` is convenient but locks
   `Global` as the de-facto choice. Should v1.0 require explicit
   allocator (no default)?

   Recommend **keep the default through v0.x, revisit at v1.0**.
   Forcing explicit allocator now is a porting tax we can't justify.

2. **Allocator handle storage in `Box`.**
   `Box<T, Arena>` could store either:
   - (a) a pointer back to the Arena (1-pointer overhead per Box)
   - (b) just a phantom type and rely on the user to know which Arena
     to free into.

   **(a)** is safer; **(b)** is zero-overhead. Rust's API does (a).
   Recommend **(a)** for safety.

   Counter: for `Pool<T>` and `Arena`, the storage location *is* the
   allocator location (same backing buffer). Could elide the back-
   pointer for those. Optimization for v0.4.

3. **Generic-over-allocator for stdlib containers.**
   Should `Vec<T>` become `Vec<T, A = Global>` in v0.3, or stay
   `Vec<T>` and ship `VecIn<T, A>` as a parallel type?

   Recommend **make `Vec<T, A = Global>`** — single canonical type,
   default param keeps existing code working. Same for `Box`,
   `String`, `HashMap`, `BTreeMap`.

4. **`Pool<T>` vs `Pool<dyn Any>`.**
   Type-specific pools are simpler. Heterogeneous pools would need
   trait-object machinery and conflict with `#[no_dyn]`.

   Recommend **type-specific pools only in stdlib**. Heterogeneous
   pools can be a community rod via raw bytes + custom destructors.

5. **TLSF parameter tuning.**
   First-level / second-level bit widths affect fragmentation vs
   speed. Defaults: FL=64, SL=32. Should this be a const generic
   parameter (`TLSF<FL, SL>`)?

   Recommend **defer until benchmarks show need**. Ship one TLSF
   variant.

6. **Async + allocators.**
   Tokio integration (Section B1 of Decisions doc) uses tokio's
   global allocator. Should we provide a `tokio_alloc` wrapper that
   surfaces it as a Nucleor `Allocator`?

   Recommend **yes for v0.5** when tokio rod ships. Until then,
   tokio code uses `Global`.

---

## 7. Definition of done

- [ ] `Allocator` trait spec'd and lives in `stdlib/rods/allocator.nr`
- [ ] `Box<T, A: Allocator = Global>` parses, type-checks, codegens
- [ ] `Vec<T, A: Allocator = Global>` parses, type-checks, codegens
- [ ] `Arena` impls `Allocator`, ships in `stdlib/rods/arena.nr`
- [ ] `Pool<T>` impls `Allocator`, ships in `stdlib/rods/pool.nr`
- [ ] `TLSF` impls `Allocator`, ships in `stdlib/rods/tlsf.nr`
- [ ] Borrow checker rejects `Box<T, Arena>` outliving its `Arena`
- [ ] `#[no_alloc(global, pool)]` (parameterized form) parses and
      enforces
- [ ] `tests/attrs/no_alloc_arena_ok.nr` etc. pass
- [ ] `tests/err/err_alloc_escape_arena.nr` etc. pass
- [ ] Benchmark shows `MAX_ALLOC_NS` claims hold within 2× on x86_64
      and ARM Cortex-M4F
- [ ] CHANGELOG documents allocator types and migration story
- [ ] Stdlib audit manifests (RFC-0001 §3.5) updated to record each
      function's allocator usage

---

## 8. Future extensions (out of scope)

- **Stack-pinned allocators** (allocate on stack frame via VLA-style
  syntax) — probably never. Stack semantics differ enough that a
  separate type makes more sense.
- **NUMA-aware allocators** for multi-socket servers — v0.7+.
- **GPU-memory allocators** (`Box<T, CUDA>`) — interesting; v0.6
  when `rod/cuda.nr` matures.
- **Custom user-defined allocators** — already supported by the
  `Allocator` trait; no compiler change needed beyond shipping the
  trait.
- **Region inference** (Cyclone-style) — v0.7+ candidate if user
  demand emerges.

---

## 9. Acceptance checklist

- [ ] Maintainer (Joseph Wescott) approves the design
- [ ] Compatible with RFC-0001's `#[no_alloc(...)]` parameterization
- [ ] Compatible with the v0.3 release schedule
- [ ] LOC estimates (~1530 compiler + ~1080 runtime) fit budget
- [ ] Migration story (default-`Global`) is acceptable
- [ ] Pitch survives ("real-time-safe allocators in the type system,
      not by convention")
