# RFC-0001 — Real-Time Function Attributes

| Field | Value |
|---|---|
| **Number** | 0001 |
| **Title** | Real-Time Function Attributes (`#[no_alloc]`, `#[no_panic]`, `#[no_dyn]`, `#[deadline]`) |
| **Status** | Implemented (audited v0.4.187). All four attributes parse + enforce: `#[no_panic]` halts with RT-002 when a panicking call (`panic`, `assert_eq`, `assert_ne`, `unwrap`, `expect`) appears in the body; `#[no_alloc]` halts with RT-001 when an allocating helper (`Vec::new`, etc.) appears; `#[deadline = <duration>]` parses (1ms / 500us / 100ns), accepted, advisory at this writing — runtime enforcement deferred to v0.5+ when `nuc-wcet` ships; `#[no_dyn]` parses + enforces (rejects `dyn Trait` calls). Attributes compose as in `#[no_alloc, no_panic, deadline = 1ms]`. |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.3.0 ("Robotics Foundation") |
| **Depends on** | RFC-0002 (Allocator Types) — soft dependency |

---

## 1. Summary

Add four function-level attributes that the type checker enforces at
compile time. Together they let users declare and the compiler
enforce that a function is suitable for hard real-time control.

```nucleor
#[no_alloc, no_panic, no_dyn, deadline = 1ms]
fn motor_control_step(s: &mut MotorState) -> Velocity {
    let err: f64 = s.target - s.measured;
    s.integral += err * s.dt;
    s.kp * err + s.ki * s.integral + s.kd * (err - s.last_err) / s.dt
}
```

A function with this signature **cannot**:
- allocate from any heap allocator (no `Box::new`, no `Vec::push` past
  capacity, no `String` operations, no global `malloc`-equivalent),
- panic (no array-bounds violations at runtime, no integer-overflow
  panics, no `unwrap()` on `Option`/`Result`, no `assert!`),
- use dynamic dispatch (no `Box<dyn Trait>`, no `&dyn Trait`),
- exceed its declared deadline at runtime.

The compiler enforces (1)–(3) statically. (4) ships in v1.0 as a
**best-effort post-hoc detector** — the compiler injects a single
elapsed-time compare at function exit and emits diagnostic `RT-004`
(plus `exit(1)`) on overrun; there is **no** hardware-timer trap or
mid-execution enforcement in v1.0. Mid-execution enforcement
(SIGALRM / SysTick / per-back-edge poll) is deferred to a follow-on
release. See §3.2.4 for the full v1.0 contract. v1.x adds a static
WCET pass that can flag deadline overruns at compile time.

This is **the headline feature of v0.3** and the centerpiece of the
"safer than Rust at runtime" pitch.

---

## 2. Motivation

### 2.1 What's wrong today

Today a Nucleor function can call `vec_push` (which may allocate),
divide by zero (which panics), call a method through a trait object
(which incurs vtable dispatch and possible cache miss), and run for
unbounded time. None of this is acceptable in a 1 kHz motor control
loop.

Users have no way to declare "this function is suitable for L1 real
time." They write the function and *hope*. The compiler does not
help.

### 2.2 What other languages do

| Language | Approach | Limitation |
|---|---|---|
| **C** | Convention. `#pragma`s. MISRA-C linter rules. | Off-by-default; advisory only |
| **C++** | `noexcept` (panic-only). `constexpr` (no runtime work). | No-alloc and deadline are not language features |
| **Rust** | `#![no_std]` + `#[no_panic]` macro crate (hack via linker error) + `#[inline(never)]` + manual review. | None of these are first-class; users assemble them by hand |
| **Ada/SPARK** | `pragma Restrictions (No_Allocators)`, `pragma Restrictions (No_Exceptions)`, deadline analysis | Gold standard. Not memory-ergonomic. Niche. |
| **MISRA-C** | Off-language ruleset enforced by external linter | Not part of the language; users must run a separate tool |

**Nobody mainstream ships all four guarantees as first-class language
features that compose cleanly with an ownership type system.**
Ada/SPARK comes closest but loses on ergonomics. Nucleor's wedge is
to ship them as first-class attributes that compose with
ownership/borrow checking.

### 2.3 What we want

A function annotated `#[no_alloc, no_panic, no_dyn, deadline = 1ms]`
should:

1. **At compile time**, have its body checked against the four
   attribute constraints. Any violation produces a diagnostic with
   the offending expression's span and a suggestion.
2. **At link time**, fail to link if it transitively calls an
   un-annotated function whose body cannot be shown to satisfy the
   constraints.
3. **At runtime**, trap with a recoverable signal if the deadline is
   exceeded (default behavior; configurable per `--profile`).

These properties must be **opt-in** — not every Nucleor function is
real-time. They must **compose with the existing ownership model**,
not replace it. They must be **inferable transitively**: a function
that calls only no-alloc functions is itself no-alloc, and the
compiler should figure that out.

---

## 3. Design

### 3.1 Attribute syntax

```nucleor
#[no_alloc]                            // single attribute
#[no_alloc, no_panic]                  // multiple, comma-separated
#[deadline = 1ms]                      // attribute with value
#[deadline = 500us]                    // microseconds
#[deadline = 100ns]                    // nanoseconds (advisory; HW timers may not have this resolution)
#[no_alloc, no_panic, no_dyn, deadline = 1ms]   // composed
```

Attributes may be specified in any order. Duplicate attributes are
an error. Values are typed `Duration` literals using the same suffixes
as `time.nr` (`ns`, `us`, `ms`, `s`).

### 3.2 The four attributes

#### 3.2.1 `#[no_alloc]`

**Forbids:** any expression whose type-system effect includes
`Effect::Alloc`.

Concretely, the following are rejected at type-check inside a
`#[no_alloc]` function:

- `Box::new(x)` — global heap
- `Vec::with_capacity(n)`, `vec_push(v, x)` if it would grow the
  backing storage (capacity-aware)
- `String::new`, `s.push_str("…")`
- `HashMap::insert` if it would resize
- Any call to a function not marked `#[no_alloc]` and not provably
  alloc-free (per §3.4 inference)
- Any `extern fn` not marked `#[ffi_no_alloc]`

**Allowed:**
- Stack-allocated locals of any size
- Pre-allocated `Vec<T>` operations that don't grow (set, swap,
  iterate, slice, in-place modify)
- Pre-allocated `Box<T>` operations (deref, mutate)
- Arena allocations from a `&Arena` parameter (since the arena's
  lifetime is owned by the caller, it's the caller's allocation
  budget). This is RFC-0002 territory but the rule is: `arena.alloc(T)`
  is permitted in `#[no_alloc]` fns iff the arena was passed in.
- All four allocator types from RFC-0002 (Arena, Pool, TLSF, Global)
  are *type-tracked*, and `#[no_alloc]` rejects only `Global`. The
  user can opt narrower with `#[no_alloc(global, pool)]`.

**Diagnostic example:**

```
error[RT-001]: allocation in #[no_alloc] function
  --> src/control.nr:14:21
   |
12 | #[no_alloc, deadline = 1ms]
13 | fn motor_step(s: &mut MotorState) {
14 |     let buf: Vec<f64> = Vec::with_capacity(1024);
   |                         ^^^^^^^^^^^^^^^^^^^^^^^^ allocates from global heap
   |
   = note: #[no_alloc] forbids global-heap allocation
   = help: pre-allocate `buf` outside the loop and pass it in by `&mut`
   = help: or take a `&Arena` parameter and use `arena.alloc::<Vec<f64>>(1024)`
```

#### 3.2.2 `#[no_panic]`

**Forbids:** any expression that may panic at runtime.

Sources of panic in Nucleor (today and post-RFC):
- Integer overflow in arithmetic (`+`, `-`, `*`) when in
  `--profile=debug` (Rust-style). In `--profile=release` Nucleor
  defaults to two's-complement wraparound, but with `#[no_panic]` we
  must prove no overflow regardless of profile.
- Integer division by zero
- Array/slice index out of bounds
- `Vec::get(i)` returning `None` and being unwrapped
- `Option::unwrap()`, `Result::unwrap()`
- `assert!`, `panic!`, `unreachable!`
- Float-to-int cast saturation (in some semantics)
- Stack overflow (recursion depth) — out of scope; flag with
  `#[deadline]` instead

**Allowed:**
- All checked-arithmetic operations (`checked_add`, `wrapping_add`,
  `saturating_add`)
- `match` with exhaustive patterns
- `Option::unwrap_or`, `Result::unwrap_or_else`, `?` operator
- Indexing with provable-in-bounds (e.g., right after a length check
  in the same basic block)
- Arena/Pool/TLSF allocations that return `Option<&T>` and are
  matched (no unwrap)

**Implementation sketch:** every expression carries a `Panics: bool`
effect bit, computed by a forward dataflow pass over IR. The
type-checker rejects `Panics = true` inside `#[no_panic]` functions.

The pass is conservative — it errs on the side of "may panic" when
in doubt. Users can inject explicit non-panic proofs via
`#[assume(x < N)]` (RFC-0004 territory).

**Diagnostic example:**

```
error[RT-002]: expression may panic in #[no_panic] function
  --> src/control.nr:18:18
   |
16 | #[no_panic, deadline = 1ms]
17 | fn pid_step(pid: &mut PID, dt: f64) -> f64 {
18 |     let inv: f64 = 1.0 / dt;
   |                    ^^^^^^^^ division may divide by zero
   |
   = help: guard with `if dt != 0.0 { 1.0 / dt } else { … }`
   = help: or use `safe_div(1.0, dt).unwrap_or(0.0)`
```

#### 3.2.3 `#[no_dyn]`

**Forbids:** dynamic dispatch.

Concretely:
- `Box<dyn Trait>` parameters or locals
- `&dyn Trait` parameters or locals
- Function pointers `fn(...) -> T` whose target is not statically
  known (function-pointer-via-known-const-fold is OK; pointer stored
  in a struct field is not)
- Calls through trait objects

**Allowed:**
- Generic functions with monomorphization (`fn f<T: Trait>(x: T)`)
- `enum`-based dispatch (Rust's "tagged-union polymorphism" pattern)
- Direct function calls

**Why a separate attribute from `#[no_alloc]`:** dyn dispatch alone
doesn't allocate, but it does cost a vtable lookup and can defeat
inlining. For L1 real-time you want both. But L2/L3 may want
`#[no_alloc]` without `#[no_dyn]` (e.g., a message dispatcher that
holds boxed handlers).

#### 3.2.4 `#[deadline = <duration>]`

**Declares** a worst-case execution time budget.

> **v1.0 enforcement semantics (Lane 6 / F-CONC-003 audit 2026-05-08).**
> The v1.0 implementation is **best-effort post-hoc detection only**.
> The compiler injects a single `__nucleor_deadline_check` call at
> function exit; the call compares wall-clock elapsed against the
> declared budget and emits diagnostic `RT-004` (and `exit(1)`) on
> overrun. There is **no** mid-execution hardware-timer trap, no
> SIGALRM-based interrupt, and no per-loop-back-edge poll today. A
> `#[deadline = 100us]` function whose body does 38 ms of work runs
> the full 38 ms before the diagnostic fires; an infinite-loop body
> never returns, so the deadline never fires at all.
>
> Adopters writing hard real-time control loops MUST treat the
> declared deadline as a developer-visible budget annotation that
> the runtime checks at the function boundary, not as an enforced
> hardware-timer trap. Mid-execution enforcement (the table below)
> is **deferred** to a follow-on release. See "Future enforcement
> profiles (deferred)" below.

**Future enforcement profiles (deferred — not v1.0).** When the
hardware-timer / SIGALRM trap path lands, the table below describes
the per-profile shape. v1.0 ships the post-hoc compare on every
profile.

| Profile | Enforcement (v1.1+) |
|---|---|
| `--profile=debug` | Runtime check via hardware timer; trap on overrun, recover via `Result<T, DeadlineExceeded>` |
| `--profile=release` | Runtime check via hardware timer; trap on overrun, behavior is `panic_handler`-defined |
| `--profile=rt-linux` | Runtime check via SIGALRM + isolcpus pinning; overrun pages the operator |
| `--profile=embedded` | Runtime check via SysTick or RTC; overrun jumps to a fail-safe handler |
| `--profile=cert` (v0.7) | **Static** WCET analysis; overrun is a compile error |

`#[deadline]` does **not** by itself imply `#[no_alloc]` or
`#[no_panic]`. They compose. But the linter warns if `#[deadline]`
appears without at least one of the others — a deadline on a function
that allocates is hard to reason about.

**Static WCET path (v0.5):** the compiler's `nuc check --wcet` mode
walks the function's IR + cost-table-per-target-arch and produces an
upper bound. Underapproximate but useful as a CI gate.

**Heptane integration (v0.7+):** for SIL-3/ASIL-D users, run Heptane
(open-source IRISA WCET analyzer) over the LLVM `MachineInstr` output
for provable bounds.

**Diagnostic example (static WCET):**

```
error[RT-004]: function exceeds declared deadline
  --> src/control.nr:25:1
   |
23 | #[no_alloc, deadline = 100us]
24 | fn ekf_update(s: &mut EkfState, z: &Vec<f64>) {
25 |     for i in 0..z.len() { /* ... */ }
   | ^^^ static WCET estimate: 437us > declared 100us
   |
   = note: dominant cost: matrix multiply at line 28 (~280us)
   = help: pre-compute matrix block-decomposition or reduce state dim
```

### 3.3 Composition rules

The four attributes compose multiplicatively. A function may have any
combination. There is no global "real-time mode" — opt-in, function
by function.

| Attribute set | Use case |
|---|---|
| (none) | Default. No constraints. |
| `#[no_panic]` | Reliability code (web servers, daemons) |
| `#[no_alloc]` | Memory-pressure-sensitive code (embedded but not real-time) |
| `#[no_alloc, no_panic]` | Embedded firmware that runs forever |
| `#[no_alloc, no_panic, no_dyn, deadline]` | L1 hard real-time |

### 3.4 Inference

The attributes are **inferred** for unannotated callees.

When function `f` is called from a `#[no_alloc]` function `g`:
1. If `f` is annotated `#[no_alloc]`, OK.
2. Else, the compiler analyzes `f`'s body. If it provably does not
   allocate, OK (and `f` is *implicitly* tagged for the purposes of
   any other `#[no_alloc]` callers).
3. Else, error at the call site, pointing to both the call and the
   offending expression in `f`.

Same algorithm for `#[no_panic]` and `#[no_dyn]`. `#[deadline]` does
not infer — it must be explicit, since it's a budget claim, not a
property.

**Why infer rather than require explicit annotation:** the stdlib has
~103 rods. Forcing every author to annotate every function would be a
massive porting tax and rules out using third-party rods. Inference
makes the attributes opt-in for *callers* without forcing annotation
on *callees*.

**Counter-argument:** explicit annotations make breaking changes
visible (a stdlib update that adds an allocation breaks downstream
real-time users). Mitigation: in v0.3, ship inference with a warning
that says "function `f` is implicitly no-alloc; consider annotating
explicitly to lock in the contract." In v0.4, add a `nuc check
--audit-rt` mode that lists all implicitly-tagged functions for
review.

### 3.5 Interaction with FFI

`extern fn` blocks are opaque to the analysis. By default, an
`extern fn` is treated as `may_alloc, may_panic, may_dispatch_dyn`.
To call C/C++ code from a `#[no_alloc]` function, the user must mark
the extern declaration:

```nucleor
extern fn libc_memcpy(dst: *mut u8, src: *const u8, n: usize)
    #[ffi_no_alloc, ffi_no_panic];
```

The `#[ffi_no_*]` attributes are **trust assertions** — the compiler
takes the user's word. A user can also provide a manifest file
(`rod_rt.audit.toml`) that lists FFI symbols and their RT properties;
the compiler reads it on import. Stdlib rods ship with audit manifests.

### 3.6 Interaction with allocators (forward to RFC-0002)

`#[no_alloc]` rejects allocation from `Allocator::Global` only by
default. Users can opt narrower:

```nucleor
#[no_alloc(global, pool)]   // rejects Global and Pool, allows Arena and TLSF
fn f() { … }
```

This requires RFC-0002's `Allocator` trait + `Box<T, A: Allocator>`
typing. If RFC-0002 slips, v0.3 ships `#[no_alloc]` as
"reject any allocation" and refines in v0.4.

### 3.7 Interaction with the existing optimizer

The 6-pass optimizer must not introduce allocations into a
`#[no_alloc]` function. This is a soundness requirement:

- **CTFE** (compile-time function execution) is fine — it runs at
  compile time, not runtime.
- **Effect-driven fusion** is fine — it eliminates intermediates,
  removing potential allocations.
- **Algebraic rewriting** must not introduce a heap-backed
  intermediate. If a `@law` rewrite would add an allocation, the
  rewrite is suppressed inside `#[no_alloc]` functions.
- **`@layout(soa)`** is fine — layout transformation, not allocation.

The compiler tracks per-pass alloc-introducing capability and either
suppresses the pass inside RT functions or proves the rewrite
allocation-free.

### 3.8 Diagnostics — error codes

| Code | Meaning |
|---|---|
| `RT-001` | Allocation in `#[no_alloc]` function |
| `RT-002` | Possibly-panicking expression in `#[no_panic]` function |
| `RT-003` | Dynamic dispatch in `#[no_dyn]` function |
| `RT-004` | Heuristic deadline estimate exceeds declared `#[deadline]` (NOT certified WCET — see §"Heuristic vs certified WCET" below) |
| `RT-005` | FFI call in RT function without `#[ffi_no_*]` annotation |
| `RT-006` | RT attribute on an `async fn` (rejected; async is non-RT) |
| `RT-007` | Deadline annotation without `no_alloc` or `no_panic` (warning) |
| `RT-008` | Recursive call in `#[deadline]` function (warning; bounded recursion OK if `#[max_depth = N]`) |

### Heuristic vs certified WCET (R03-D3, v0.8.289)

RT-004 today is a **heuristic deadline-overrun estimate, NOT a
certified WCET model.** The pass at `nucleor_s1_compiler.nr` (T3.3,
shipped v0.3.2) counts statement terminators and applies a coarse
loop multiplier to estimate µs cost. It deliberately does NOT
model:

- callee cost (helpers / rod calls are invisible — an `O(n)`
  helper inside a tight loop does not contribute to the estimate),
- ISA / cache / branch-prediction effects,
- string-literal `;` or comment-`while` (false-positive surface),
- non-loop control-flow weight (`if` arms, `match`, recursion).

The estimator's job is to flag bodies that *look* expensive
relative to `#[deadline]` so adopters investigate before shipping;
it is NOT a guarantee. Users should suppress with
`#[allow(RT-004)]` (file-wide) or `#[allow_fn(RT-004)]` (per-fn)
when the estimate is wrong, and treat the runtime deadline check
(hardware-timer trap on overrun) as the actual real-time
contract.

A certified WCET / cost-table pass (Heptane / IRISA-style or a
Nucleor-native cost-table contract) is Phase 2 work tracked under
this RFC. When it lands, RT-004 will split into two diagnostics
(`RT-004-heuristic` warning + `RT-004-certified` error), with the
heuristic remaining as a fast early signal.

---

## 4. Implementation

### 4.1 Compiler changes

| Component | Change | LOC est. |
|---|---|---|
| Lexer | Recognize attribute tokens (`#`, `[`, `]`, `=`, duration literals) | ~50 |
| Parser | Parse `#[attr(value)]` syntax on `fn` decls | ~150 |
| AST | New `FnAttributes` field on `FnDecl` | ~30 |
| Type checker | Inference passes for no_alloc/no_panic/no_dyn (forward dataflow over IR) | ~800 |
| IR | `Effect` bitset on every IR instruction (alloc, panic, dyn) | ~200 |
| Codegen | `#[deadline]` → emit hardware-timer setup at function entry, check at exit | ~150 |
| Diagnostics | RT-001…RT-008 with span tracking, suggestions | ~400 |
| **Total** | | **~1800** |

This is moderate — comparable in scope to the v0.1.5 audit cleanup.

### 4.2 Runtime changes

| Component | Change | LOC est. |
|---|---|---|
| `runtime/rt_deadline_rt.c` | Hardware-timer wrappers per platform | ~300 |
| `runtime/rt_panic_rt.c` | `#[no_panic]` runtime — assert-only-in-debug | ~50 |
| `runtime/rt_alloc_audit_rt.c` | Audit manifest reader | ~100 |
| **Total** | | **~450** |

### 4.3 Stdlib changes

Audit and annotate the 103 rods. The audit manifest is mechanical:

- Math/numeric rods (`taylor`, `interval`, `bigint`, `fft`, etc.) —
  mostly `no_alloc, no_panic` after small fixes
- Tensor/linalg rods — `no_alloc` if user pre-allocates output
- I/O rods (`io`, `socket`, `serial`) — `may_alloc, may_panic`,
  must NOT be called from RT
- Concurrency rods — `may_alloc`, may NOT be called from RT
- Robotics rods (when added in v0.3) — designed `no_alloc`, `no_panic`,
  `no_dyn` from the start

Estimated ~2 days per rod, ~200 rod-days total. Front-loaded onto v0.3
work.

### 4.4 Test plan

- **Unit tests** (`tests/attrs/`): one test per attribute, one test
  per error code RT-001…RT-008.
- **Negative tests** (`tests/err/`): `err_rt_alloc_in_no_alloc.nr`,
  `err_rt_panic_in_no_panic.nr`, etc.
- **Integration tests** (`tests/features/`): a fully-annotated
  PID controller in `features/pid_rt.nr` that compiles, builds, and
  runs at 1 kHz on the host (best-effort timing without hardware).
- **Showcase** (`examples/13_realtime_control.nr`): a control loop
  with all four attributes, demonstrating the diagnostic for each
  violation in commented-out code.

### 4.5 Migration

`#[no_alloc]` etc. are purely additive. Existing code is
unaffected; RT attributes are opt-in.

The one breaking change: stdlib rods that get audit manifests with
`may_alloc = true` (e.g., `vec_push` for unbounded vec) will
continue to compile from non-RT code unchanged, but will now error
when called from an RT function. This is the intended behavior; we
don't consider it a breaking change in the SemVer sense (it's a new
diagnostic on previously-undefined code).

---

## 5. Alternatives considered

### 5.1 Effects system (Koka-style)

We considered modeling alloc/panic/dyn as compiler-tracked **effects**
in the type system (per RFC-0001's earlier draft and the V1 quarantine
of `pure fn` / `requires [io.read]` syntax). Effects are more
expressive — you could write `pure fn` and have it inferred.

**Why we picked attributes instead:**
1. Effects are a heavyweight type-system feature. Every function
   signature carries effect annotations. Most users don't want this
   tax.
2. Attributes compose with Nucleor's existing ownership model with no
   refactor. Effects would require a parallel inference pass and
   significant compiler work.
3. We *can* unify under effects later (v0.7+) — the attributes desugar
   to effect rows. Choosing attributes now doesn't preclude effects
   later.

### 5.2 `#![profile = "rt"]` crate-level attribute

We considered a single crate-level switch: "this whole crate is
real-time." Rejected because:
1. Most real-time code lives in a few hot functions inside an
   otherwise non-RT codebase. Crate-level forces too much.
2. Granularity matters for stdlib rods — `vec_get` is RT,
   `vec_push` (with grow) is not. A whole-rod switch would over-tag.

### 5.3 Linter tool, not language feature

We considered shipping the four checks as `nuc lint` only, not
language-enforced. Rejected because:
1. Linters drift out of date with code. Compile-time checks don't.
2. Linters are easy to disable per-line. Compile-time guarantees
   are not.
3. Shipping these as language features is the unique pitch. If
   they're a linter, Nucleor is just "Rust + a linter." We want the
   stronger story.

### 5.4 Mark un-RT functions instead of RT functions

We considered defaulting all functions to RT and requiring
`#[may_alloc]` for non-RT. Rejected:
- Tons of false-positive errors on existing code.
- Forces explicit annotation everywhere even for one-shot scripts.
- Inference handles the common case (calling RT-safe code from RT
  context) without forcing global tags.

---

## 6. Open questions

1. **`#[no_panic]` granularity for arithmetic overflow.** Two choices:
   - (a) Reject `+`/`-`/`*` in `#[no_panic]` unless using
     `wrapping_add`/`checked_add`/`saturating_add`.
   - (b) Accept `+`/`-`/`*`, infer wraparound semantics in release
     and trap in debug, treat the trap as panic-equivalent.

   Recommend **(a)** — explicit is better. Make the compiler
   suggest the right alternative.

2. **`#[deadline]` resolution on hardware without a high-resolution
   timer** (some MCUs only have 1 ms tick). Should the compiler
   reject `deadline = 100us` on those platforms, or round up?

   Recommend **reject with a per-target capability check**. Better
   to fail at compile time than silently miss a budget.

3. **`#[deadline]` composition across nested calls.** If `f()` has
   `deadline = 1ms` and calls `g()` with `deadline = 500us`, is the
   compiler smart enough to verify `g()` fits in `f()`'s budget?

   Recommend **yes for v0.5 static-WCET** (the analysis sees the call
   tree); **no for v0.3 runtime-checked** (each function checks
   independently). Note in docs.

4. **Should `#[no_panic]` reject explicit `panic!()` calls?** Trivially
   yes — but should it also reject explicit `unreachable!()` calls,
   which the user is asserting can't happen?

   Recommend **reject `unreachable!()` too** — if the user can prove
   it's unreachable, they can prove it via a `match` instead. Enforce
   the discipline.

5. **Dyn dispatch via function pointers stored in pure-data
   structures.** A `struct Handler { f: fn(Msg) -> Reply }` doesn't
   look like dyn dispatch but acts like it. Is `#[no_dyn]` violated?

   Recommend **yes if the function pointer is read from heap memory**;
   **no if it's a const-known compile-time value**. Track via
   const-folding analysis.

6. **Async functions.** Should `async fn` with RT attributes even be
   possible? Recommend **no — RT attributes on `async fn` is
   error RT-006**. Async is non-deterministic by design.

---

## 7. Definition of done

This RFC is implemented when:

- [ ] All four attributes parse and round-trip through the AST.
- [ ] Type checker enforces `no_alloc`, `no_panic`, `no_dyn` with
      diagnostics RT-001…RT-005, RT-007.
- [ ] Inference works: a function calling only no-alloc functions is
      itself implicitly no-alloc, and the compiler proves it.
- [ ] Codegen emits hardware-timer setup for `#[deadline]` on at
      least Linux x86_64 (SIGALRM-based) and Windows x86_64
      (timeSetEvent-based). Embedded targets follow in v0.6.
- [ ] All 103 rods have audit manifests classifying their RT
      properties.
- [ ] `tests/attrs/no_alloc.nr`, `tests/attrs/no_panic.nr`,
      `tests/attrs/no_dyn.nr`, `tests/attrs/deadline.nr` pass.
- [ ] `tests/err/` gains 8 negative tests, one per error code.
- [ ] `tests/features/pid_rt.nr` compiles, runs, and demonstrates a
      sub-1ms control loop in the v0.3 release notes.
- [ ] `examples/13_realtime_control.nr` ships as a showcase.
- [ ] CHANGELOG documents the new attributes and the audit-manifest
      mechanism.
- [ ] `Nucleor-Safe-Subset.md` (preview) lists which combinations
      meet the v0.6 safety subset.

---

## 8. Future extensions (out of scope for this RFC)

- **`#[max_depth = N]`** for recursion bounds (RFC-0006).
- **`#[const_fn]` interaction with `#[no_alloc]`** — const-fns are
  trivially no-alloc since they execute at compile time.
- **`#[atomic]`** for lock-free data structures (RFC-0007).
- **`#[isr]`** for interrupt-service-routine functions, which imply
  all four attributes plus rejection of any blocking call (RFC-0008).
- **Per-allocator `#[no_alloc(...)]` granularity** — covered by the
  RFC-0002 allocator-types work.
- **Static WCET via Heptane** — RFC-0009.

---

## 9. Acceptance checklist (sign-off before implementation)

- [ ] Maintainer (Joseph Wescott) approves the design
- [ ] No conflicts with RFC-0002 (allocator types) or RFC-0003 (typed
      frames) — both are downstream of this RFC and depend on its
      attribute-parsing infrastructure
- [ ] Compatible with the v0.3 release schedule (3–4 month window)
- [ ] LOC estimates (~1800 compiler + ~450 runtime + ~200 rod-days)
      fit in a single-developer-quarter budget
- [ ] The five-line pitch survives ("safer than Rust at runtime,
      because no_alloc/no_panic/no_dyn/deadline are first-class")
