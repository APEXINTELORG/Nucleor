# Nucleor — Memory Safety, Borrow, and Ownership: Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC (one document, two halves)
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS` while drafting this. This document lives at the absolute path given at the bottom; it is the artifact for hand-off to the main agent that will perform the actual closure work.

---

# Part I — Definitions

## 1.1. Three distinct concepts, one foundation

The three terms are routinely conflated. They are not the same thing. Treating them as one word is the root cause of half the gaps in this document.

- **Ownership** — *who has the right to free a value*. A property of bindings. Tracked by move semantics. Diagnostics: OWN-001, OWN-008.
- **Borrow** — *who has temporary access to a value without taking ownership of its lifetime*. A property of references. Tracked by aliasing-XOR-mutation rule. Diagnostics: OWN-002, OWN-003, OWN-004, OWN-005, OWN-007, OWN-011.
- **Memory safety** — *the eight runtime guarantees the type system promises to enforce*. A property of the program as a whole. The end state that ownership and borrow exist to produce.

Ownership and borrow are *mechanisms*. Memory safety is the *guarantee*. A working borrow checker is not memory safety; it is one of the mechanisms that produces memory safety. Confusing the two leads to "we have a borrow checker, therefore we are memory-safe" reasoning, which is false.

## 1.2. The eight memory-safety guarantees (MS-1 through MS-8)

A program is memory-safe if and only if all eight of these hold for every execution path:

| Code | Guarantee | One-line definition |
|---|---|---|
| **MS-1** | No use-after-free | A reference cannot be used after its underlying allocation has been released |
| **MS-2** | No double-free | An allocation is released exactly once |
| **MS-3** | No use-after-move | A binding whose value has been moved cannot be read or written |
| **MS-4** | No out-of-bounds | Vec/String/array indexing cannot read or write outside the allocated region |
| **MS-5** | No null-pointer dereference | A reference is never null; optional values use `Option<T>` |
| **MS-6** | No data race | Two threads cannot concurrently access the same location with at least one access being a write, without synchronization |
| **MS-7** | No uninitialized read | A value cannot be read before it is initialized |
| **MS-8** | No type confusion / structural punning | A value of type T cannot be reinterpreted as type U through aliasing |

## 1.3. The seven borrow-validation categories (BR-1 through BR-7)

| Code | Category | One-line definition |
|---|---|---|
| **BR-1** | Shared borrow correctness | `&T` permits multiple readers, no writers |
| **BR-2** | Mutable borrow correctness | `&mut T` permits one writer, no other readers |
| **BR-3** | Aliasing XOR mutation | The two cannot coexist on the same value |
| **BR-4** | Field-disjoint borrows | Borrowing non-overlapping struct fields simultaneously is permitted |
| **BR-5** | Scope release | Borrows are released at lexical scope exit |
| **BR-6** | Conditional-branch divergence | Borrows taken in one `if` arm but not the other are handled correctly at the merge point |
| **BR-7** | Lifetime-parameter runtime safety | Code using `<'a>` lifetime annotations is runtime-safe even when the static enforcement is incomplete |

## 1.4. The five ownership-validation categories (OWN-VAL-1 through OWN-VAL-5)

These are validation categories, not diagnostic codes. They map to the existing OWN-* diagnostics but specify what *behavior* must be validated.

| Code | Category | One-line definition |
|---|---|---|
| **OWN-VAL-1** | Move on assignment | Non-copy values transfer ownership on `=` |
| **OWN-VAL-2** | Move on function call | Non-copy values transfer ownership when passed by value |
| **OWN-VAL-3** | Copy semantics for primitives | i64/i32/f64/bool/str do not move; both source and destination remain valid |
| **OWN-VAL-4** | Auto-drop at scope exit | When auto-drop is in effect, values are released exactly once at scope exit on every path including early return |
| **OWN-VAL-5** | Conditional-path ownership convergence | A value moved in one branch but not another is handled correctly at the merge point |

---

# Part II — Gap Analysis

## 2.1. Memory-safety gaps (MS-1 through MS-8)

### MS-1 — Use-after-free
**Status: PARTIAL. Largest open gap in the memory-safety surface.**

What works:
- Move semantics prevent the obvious use-after-free pattern: once a value is moved into a function that frees it, the source binding is dead and the checker will fire OWN-001 on any subsequent use.
- Scope-bound arena tracking (`@region(name)`) prevents arena allocations from being used after arena destruction.
- `str` is reference-counted; refcount semantics prevent the str-specific use-after-free class.

What's broken:
- Heap collections (`Vec`, `String`, `HashMap`, `HashSet`, `BTreeMap`, `BTreeSet`, `VecDeque`, `Box`) require manual `vec_free` / `string_free` / equivalent. Forgetting the free is a leak; calling free while a pointer to the collection is still live elsewhere is a use-after-free.
- Auto-drop / RAII / Drop trait is **deferred to v1-class**. There is a `#[auto_drop]` per-fn opt-in spike, but it is not in the compiler gate and not stable.
- The ownership checker tracks identifiers, not heap locations. If you alias a Vec's i64 handle into another binding, the checker sees two values and won't catch use-after-free through the alias.

Concrete failure scenario today:
```nucleor
let v: Vec<i64> = vec_new();
let alias: i64 = v;          // i64 handle copied; checker sees 'alias' as independent
vec_free(v);                 // v's allocation released
let x: i64 = vec_get(alias, 0);  // USE-AFTER-FREE — checker does not catch this
```

### MS-2 — Double-free
**Status: PARTIAL. No named compile-time diagnostic.**

What works:
- Move semantics prevent the obvious double-free: once a value is moved into `vec_free`, the source binding is dead and a second `vec_free(v)` would fire OWN-001 first.
- The ownership checker correctly enforces single-move-into-consuming-function for the well-typed case.

What's broken:
- Same as MS-1: aliased i64 handles defeat the checker. Two bindings holding the same Vec pointer can each be passed to `vec_free` and the checker won't see the double-free.
- There is no named diagnostic code for double-free (no `OWN-012` or equivalent). The failure mode is undefined behavior in the runtime, not a compile-time error or runtime panic.
- `vec_free` is not idempotent — calling it twice on the same allocation corrupts the heap.

Concrete failure scenario today:
```nucleor
let v: Vec<i64> = vec_new();
let alias: i64 = v;
vec_free(v);
vec_free(alias);             // DOUBLE-FREE — heap corruption, no diagnostic
```

### MS-3 — Use-after-move
**Status: STRONG. The mature path.**

What works:
- OWN-001 is the most-tested diagnostic in the compiler.
- Move tracking through binding chains is correct.
- Conditional-branch divergence is partially handled (branches that move uniformly are fine; branches that diverge fire a diagnostic).
- 16+ negative tests in `tests/err/` cover the main shapes; `move_comprehensive.nr` is in `tests/features/`.

What's incomplete:
- Cross-function move tracking (a function returns a value that the caller knows is moved) relies on type signatures, not on full inference. Most uses are correct but the surface is not exhaustively validated.
- Conditional-path ownership convergence (OWN-VAL-5) where a value is moved in one branch but not another is sometimes too conservative (rejects valid code) and not consistently tested.

### MS-4 — Out-of-bounds access
**Status: STRONG for safe code, ABSENT for FFI raw pointers.**

What works:
- `vec_get` / `vec_set` are bounds-checked at runtime. Out-of-bounds index panics, does not corrupt memory.
- String indexing is bounds-checked.
- `str_substring` is bounds-checked (after the v0.3.205 perf-regression fix that recovered correctness).
- Slice patterns on Vec destructure correctly within bounds.

What's broken:
- FFI boundaries (`extern fn foo(p: i64) -> i64`) accept raw i64-as-pointer values with no bounds metadata. The C runtime can read or write outside the intended region without any compile-time or runtime check.
- Rod implementations that take an i64 length parameter from user code and use it to index into a buffer are vulnerable to user-supplied-length attacks if the rod doesn't validate.

### MS-5 — Null-pointer dereference
**Status: PARTIAL. Convention-only at the FFI boundary.**

What works:
- In safe Nucleor code, there is no null. `Option<T>` is the way to express absence; match exhaustiveness ensures every code path handles `None`.
- The `?` operator on `Option<T>` correctly short-circuits on `None`.

What's broken:
- `extern fn foo() -> i64` returning a pointer-encoded i64 of zero (null) gets used directly without an `Option<T>` wrap. The user-side wrapping discipline at the rod boundary is not compiler-enforced.
- The compiler has no annotation like `extern fn foo() -> Option<*mut T>` that would treat zero-as-None and nonzero-as-Some at the type level.
- A buggy rod implementation can return 0 from a fn typed to return a Vec handle, and the next `vec_get` call will null-dereference.

### MS-6 — Data race
**Status: PARTIAL. `Sendable` is first-pass.**

What works:
- `AtomicI64` with proper `load`/`store`/`fetch_add`/`CAS` operations is shipped and correct.
- Mutex (`conc_mutex`/`conc_lock`/`conc_unlock`) is shipped and correct.
- Channels (`channel_new`/`chan_send`/`chan_recv`) provide safe message-passing.
- Capability tokens (`SchedulerCap`/`RandomCap`/`FsCap`/`NetCap`) are tracked through the type system; functions that use them must declare the capability.

What's broken:
- `Sendable` marker trait is in **first-pass scope** (RFC-0035 partial). The propagation through nested types is not complete.
- A non-Sendable Vec captured into a `spawn { }` block may or may not fire RACE-001 depending on the propagation path. The diagnostic is best-effort, not a complete proof.
- `actor` isolation is partial.
- Cross-thread mutation through aliased i64 handles bypasses the entire system, same as MS-1/MS-2.

### MS-7 — Uninitialized read
**Status: STRONG.**

What works:
- `let x = expr;` requires an initializer; the compiler rejects `let x;`.
- Struct partial initialization is checked: struct literals must specify all fields.
- Match arms must produce a value of the expected type; uninitialized binding is not reachable.
- This is one of the cleanest guarantees in the language today.

What's incomplete:
- Validation evidence is implicit (everything compiles correctly), not explicit (no dedicated stress test set targeting this guarantee).

### MS-8 — Type confusion / structural punning
**Status: STRONG for safe code, with one controlled exception.**

What works:
- Distinct types in IR. The compiler does not let you bit-cast a struct of one type to a struct of another.
- The `as` cast operator is controlled and width-aware (truncation, sign extension, float-int conversion all explicit).
- Match patterns on enums correctly enforce variant tags.

The one controlled exception:
- The `i64`-everywhere closure/fn-ptr/Vec-handle pattern. All values flow through i64 at the ABI level. This is a known controlled punning exception with well-defined semantics — the compiler emits the right loads and stores at each use. It is documented and intentional.
- `f64` is bit-cast through `i64` for ABI purposes; this round-trip is bit-preserving and reversible.

What's incomplete:
- `unsafe { }` regions can violate this guarantee; the validation has no audit of unsafe blocks.

---

## 2.2. Borrow gaps (BR-1 through BR-7)

### BR-1 — Shared borrow correctness
**Status: SHIPPED.**

`&T` parses, lowers, and is correctly checked. Multiple shared borrows can coexist. Tests in `tests/features/borrow_basic.nr` and `borrow_comprehensive.nr` confirm the positive path.

### BR-2 — Mutable borrow correctness
**Status: SHIPPED.**

`&mut T` parses, lowers, and is correctly checked. Single mutable borrow exclusivity is enforced. Tests in `tests/features/mut_borrow_basic.nr` and `mut_borrow_fn_param.nr` confirm.

### BR-3 — Aliasing XOR mutation
**Status: SHIPPED with one limit.**

The borrow rule is enforced at the binding level. OWN-004 (two simultaneous mut borrows) and OWN-005 (shared borrow while mut borrow is live) fire correctly.

The limit: the checker tracks bindings, not heap locations. Aliased i64 handles bypass the rule. This is the same root cause as MS-1, MS-2, MS-6 — all four are downstream of "checker tracks identifiers, not heap aliases."

### BR-4 — Field-disjoint borrows
**Status: SHIPPED.**

Borrowing `p.left` and `p.right` simultaneously is allowed when fields don't alias. Confirmed by `err_field_shared_mut_conflict.nr`.

### BR-5 — Scope release
**Status: SHIPPED.**

Borrows are released at the closing brace of the lexical scope that contained them. Subsequent borrows at the same scope level take their place correctly.

### BR-6 — Conditional-branch divergence
**Status: PARTIAL.**

A borrow taken in one `if` arm but not the other is sometimes handled too conservatively (rejecting valid code) and not consistently tested. Same root cause as OWN-VAL-5.

### BR-7 — Lifetime parameter runtime safety
**Status: BROKEN — the largest borrow gap.**

The syntax `fn f<'a>(x: &'a str) -> &'a str` parses cleanly. The lexer accepts the lifetime tokens, the parser builds the AST, the function compiles.

**The borrow checker does NOT actually enforce the lifetime annotation.** It is decorative. A function that returns a reference derived from its inputs cannot be statically proven safe. The function compiles, runs correctly when used correctly, and silently breaks if a caller ever holds the returned reference past the input's lifetime.

**This is the single most consequential gap in the borrow story.** Any user looking at Nucleor and seeing `<'a>` syntax will reasonably assume Rust-equivalent enforcement. Today, that assumption is wrong.

Concrete failure scenario today:
```nucleor
fn first_word<'a>(s: &'a str) -> &'a str {
    // returns slice into s
    str_substring(s, 0, find_space(s))
}

fn caller() -> str {
    let s: str = make_temp_string();
    let w: str = first_word(&s);
    drop(s);                  // s is dropped (or moved away)
    w                         // RETURN OF DANGLING REFERENCE — compiler does not catch
}
```

### Cross-cutting borrow limits

**Limit X-1: Identifier-level tracking, not heap-location tracking.** Aliased i64 handles defeat the checker. Affects BR-3, MS-1, MS-2, MS-6.

**Limit X-2: No interprocedural borrow inference.** Without lifetime parameter enforcement, the checker can't reason about borrows that cross function boundaries. Workaround: most rod APIs use i64 handles instead of `&T`/`&mut T`, which loses the borrow guarantees entirely.

---

## 2.3. Ownership gaps (OWN-VAL-1 through OWN-VAL-5)

### OWN-VAL-1 — Move on assignment
**Status: SHIPPED.** OWN-001 fires correctly. Heavily tested.

### OWN-VAL-2 — Move on function call
**Status: SHIPPED.** Pass-by-value moves the value. Tests in `tests/err/err_use_after_move_fn_call.nr` etc. confirm.

### OWN-VAL-3 — Copy semantics for primitives
**Status: SHIPPED.** i64/i32/f64/bool/str are copy-typed; the copy table is in the type registry. No use-after-move on copy types.

One subtlety: `str` is reference-counted, so "copy" means "increment refcount." This is sound but conceptually distinct from primitive copy. Worth a validation case to confirm refcount semantics under stress.

### OWN-VAL-4 — Auto-drop at scope exit
**Status: BROKEN — the second-largest open gap (after BR-7).**

Auto-drop / RAII / Drop trait is **not in effect**. Heap collections require manual `vec_free` / `string_free`. The `#[auto_drop]` per-fn opt-in is a draft spike, not stable, not in the compiler gate.

This is the structural reason MS-1 (use-after-free) is a partial guarantee. Without auto-drop, the user is responsible for matching every alloc with a free, on every code path including early returns. In any non-trivial program, this discipline fails.

### OWN-VAL-5 — Conditional-path ownership convergence
**Status: PARTIAL.**

A value moved in one branch but not another is sometimes handled too conservatively (rejects valid code that would be sound), sometimes correctly. Inconsistent and not exhaustively tested.

---

## 2.4. The unsafe audit gap

**Status: ABSENT.**

`unsafe { }` blocks can violate any of MS-1 through MS-8. They are the documented escape hatch and are necessary for FFI/system code. But:

- There is no inventory of every `unsafe { }` block in the OSS compiler and stdlib.
- There is no requirement that an `unsafe { }` block carry a soundness comment explaining why it is sound.
- There is no requirement that an `unsafe { }` block be paired with a property test exercising the invariant the unsafe code depends on.

Until the unsafe surface is inventoried and each block has a documented soundness argument, the memory-safety claim of the language as a whole rests on assumptions nobody has stated.

---

## 2.5. Summary of gaps

| ID | Gap | Severity | Class |
|---|---|---|---|
| **G-1** | Auto-drop / RAII not in effect; manual `vec_free` discipline required | **CRITICAL** | OWN-VAL-4 / MS-1 |
| **G-2** | Lifetime parameters parse but borrow checker does not enforce | **CRITICAL** | BR-7 |
| **G-3** | Borrow checker tracks identifiers, not heap aliases | **HIGH** | X-1 / MS-1 / MS-2 / MS-6 |
| **G-4** | No named compile-time diagnostic for double-free | **HIGH** | MS-2 |
| **G-5** | FFI boundary nullable returns are convention-only | **HIGH** | MS-5 |
| **G-6** | `Sendable` marker propagation is first-pass; data race freedom is not a complete proof | **HIGH** | MS-6 |
| **G-7** | `unsafe { }` blocks have no audit, soundness comment requirement, or property tests | **HIGH** | All MS |
| **G-8** | Conditional-branch divergence in ownership/borrow is inconsistent and under-tested | **MEDIUM** | OWN-VAL-5 / BR-6 |
| **G-9** | FFI raw-pointer arguments and lengths are not bounds-checked | **MEDIUM** | MS-4 |
| **G-10** | Cross-function ownership/borrow inference does not exist | **MEDIUM** | X-2 |
| **G-11** | MS-7 (uninitialized read) has no dedicated stress test set despite being structurally sound | **LOW** | MS-7 |

---

# Part III — RFC: Closing the Gaps

## 3.1. Goals

1. **Promote memory safety from an aspirational property to an enforced, validated, named pillar of the language.**
2. **Close the two CRITICAL gaps (G-1, G-2) before any v1.0 release.** Ship without these closures and the Rust-style memory-safety claim is not honestly defensible.
3. **Close the four HIGH gaps (G-3, G-4, G-5, G-6, G-7) before declaring memory-safety validation complete for any feature ring.**
4. **Track the MEDIUM and LOW gaps as known limitations with explicit disclosure in the validation evidence package.**
5. **Do all of this without compromising existing behavior.** No regressions in shipped code; auto-drop and lifetime enforcement land as opt-in first, then default.

## 3.2. Non-goals

- Full Rust-level lifetime inference with non-lexical lifetimes (NLL), variance, higher-ranked trait bounds, etc. Lifetime *parameter enforcement at the simple level* is the goal. NLL and beyond are post-v1.
- A new memory model (relaxed-memory-model formalization). The existing capability-and-effect system stays as the load-bearing model.
- Replacing the i64-everywhere ABI with typed pointers. That's a larger architectural change. The closures here work within the existing ABI.
- Heap-shape analysis or pointer aliasing analysis at the compiler level. The closures here use a combination of type system + runtime instrumentation, not whole-program static analysis.

## 3.3. Closure plan, by gap

### G-1 — Auto-drop / RAII not in effect

**Phase 1 (immediate): Stabilize `#[auto_drop]` opt-in attribute.**
- Promote `#[auto_drop]` from draft spike to gated stable feature.
- Add to the compiler's pass pipeline as an enforced attribute.
- Add positive tests: a function annotated `#[auto_drop]` that allocates a Vec and returns without freeing must produce identical observable behavior to one that explicitly calls `vec_free` at scope exit.
- Add negative tests: `#[auto_drop]` on a function that contains an unsafe handle alias must fire a diagnostic.

**Phase 2 (short-term): Drop trait + scope-exit insertion.**
- Implement `Drop` trait — types implementing `Drop::drop(self)` get the cleanup call inserted at scope exit.
- Built-in implementations: `Drop for Vec<T>`, `Drop for String`, `Drop for HashMap<K,V>`, `Drop for HashSet<T>`, `Drop for BTreeMap<K,V>`, `Drop for BTreeSet<T>`, `Drop for VecDeque<T>`, `Drop for Box<T>`.
- The compiler inserts the drop call at every scope-exit path including early returns, panic-unwind paths (where applicable), and conditional-branch convergence points.

**Phase 3 (v1.0 gate): Make auto-drop the default.**
- Remove the `#[auto_drop]` opt-in requirement; drop becomes the default behavior for all types implementing `Drop`.
- Manual `vec_free` calls become permitted but unnecessary; the compiler suppresses the auto-drop if a manual free was already called.
- Migrate the rod stdlib to remove redundant manual `vec_free` calls.

**Acceptance:** every Ring 0 and Ring 1 feature, validated under both `#[auto_drop]` opt-in and (Phase 3) default-on, shows zero leaked allocations under `NUC_TRACE_ALLOC=1` for all positive test paths.

### G-2 — Lifetime parameters parse but borrow checker does not enforce

**Phase 1 (immediate): Diagnostic-only mode.**
- Compiler accepts `<'a>` annotations as today.
- Compiler emits a warning `BR-7` for every lifetime annotation present in user code, with text: "Lifetime annotation present but not yet enforced; runtime safety is not statically guaranteed for this function."
- This warning surfaces the gap to every user who writes lifetime code, instead of silently appearing to enforce it.

**Phase 2 (short-term): Simple lifetime checking.**
- Implement single-input single-output lifetime correspondence: `fn f<'a>(x: &'a T) -> &'a U` is enforced as "the returned reference cannot outlive `x`."
- Implement multi-input single-output: `fn f<'a, 'b>(x: &'a T, y: &'b T) -> &'a U` enforces correspondence with `x`, not `y`.
- Reject return-of-local-borrow: `fn bad() -> &str { let s = make(); &s }` — local borrow's lifetime ends at function return; this is rejected with a clear diagnostic.

**Phase 3 (medium-term): Cross-function borrow inference.**
- Function signatures with lifetime parameters propagate constraints to callers.
- A caller holding `&mut x` cannot pass `&x` to a function that itself captures `&mut x` (the constraint is visible through the lifetime parameters).

**Phase 4 (v1.0 gate): BR-7 warning becomes BR-7 error.**
- The opt-out diagnostic-only mode is removed.
- Lifetime annotations must be valid; the compiler enforces.
- Any code that compiled under Phase 1's warning-only mode and is unsound is rejected.

**Acceptance:** every lifetime-using function in the rod stdlib and example tree compiles under Phase 4 enforcement. Negative tests for return-of-local-borrow, dangling-reference, and outliving-input all fire correctly.

### G-3 — Borrow checker tracks identifiers, not heap aliases

**Phase 1 (immediate): Document the limitation and disclose in evidence.**
- Validation evidence package records "Borrow checker tracks identifiers, not heap aliases. Aliased i64 handles defeat the checker." at the cover-page level.
- Every rod that exposes an i64-handle API gets a note in its docs about this limit.

**Phase 2 (short-term): Runtime instrumentation.**
- Add a debug-mode allocation table: every `vec_new`, `string_new`, etc. registers the allocation in a table keyed by the pointer.
- `vec_free` etc. removes the entry; reuse of the pointer (via a stale alias) is detected at the next runtime use because the table lookup fails.
- This is an `NUC_TRACE_ALLOC=1` extension; the overhead is non-zero but bounded, and it is not enabled in release builds.

**Phase 3 (medium-term): Discourage handle aliasing in the rod APIs.**
- Migrate rod APIs from i64-handle returns to typed wrappers (a one-field struct that wraps the handle).
- The wrapper struct participates in move semantics; copying it requires explicit `let alias: TypeName = source.clone()` and the clone implementation does the right thing for that type.
- This converts the alias problem from "checker invisible" to "checker tracks the wrapper, not the handle inside it" — the checker is still tracking identifiers, but identifiers now correspond to allocations 1:1 because the wrapper can't be silently aliased.

**Phase 4 (v1.0 gate): All built-in collection types use wrapper structs, not raw i64 handles.**

**Acceptance:** for every collection type, the alias-then-double-free scenario from the gap analysis is either (a) caught by the checker because the wrapper move-tracking sees the alias, or (b) caught at runtime by the debug-mode allocation table.

### G-4 — No named compile-time diagnostic for double-free

**Phase 1 (immediate): Add OWN-012 diagnostic code.**
- Reserve OWN-012 as "double-free detected at compile time."
- Add the explain text and fix text following the existing OWN-* pattern.
- Initially the diagnostic fires only in the cases the checker can prove: passing the same identifier twice to a `Drop`-consuming function.

**Phase 2 (short-term): Runtime double-free detection.**
- The debug-mode allocation table from G-3 Phase 2 also catches double-frees: `vec_free` on an already-freed pointer fails the table lookup and panics with a clear message.

**Phase 3 (medium-term): Idempotent free.**
- Promote built-in `vec_free` etc. to idempotent: freeing an already-freed allocation is a no-op (in debug mode it panics, in release it silently no-ops).
- This protects against the alias-double-free pattern even without the checker catching it.

**Acceptance:** double-free at compile time fires OWN-012; double-free at runtime fires panic in debug mode; double-free at runtime is a no-op in release mode.

### G-5 — FFI boundary nullable returns are convention-only

**Phase 1 (immediate): Document the convention.**
- Every rod's FFI boundary documents which returns can be null.
- Every rod's wrapper layer null-checks the return before producing a wrapped value.

**Phase 2 (short-term): `extern fn ... -> Option<*mut T>` syntax.**
- Add syntax for FFI returns that may be null.
- The compiler treats zero as `None` and nonzero as `Some(...)` at the type level.
- Existing `extern fn ... -> i64` returns continue to work unchanged.

**Phase 3 (v1.0 gate): All built-in rod FFI boundaries that can return null use the new syntax.**

**Acceptance:** every nullable FFI return in the rod stdlib uses `Option<*mut T>` syntax; calling code must match on the result before using the inner pointer.

### G-6 — `Sendable` marker propagation is first-pass

**Phase 1 (immediate): Audit `Sendable` propagation through nested types.**
- Inventory every type in the rod stdlib for Sendable status.
- Document the propagation rules: "a struct is Sendable iff all its fields are Sendable; a Vec<T> is Sendable iff T is Sendable; etc."
- Add tests: every non-Sendable type captured into `spawn { }` produces RACE-001.

**Phase 2 (short-term): Complete the propagation.**
- Implement Sendable as a fully propagated marker through nested types.
- Add Send and Sync separation if the use case requires (Send = can transfer ownership across threads; Sync = `&T` is Send).

**Phase 3 (v1.0 gate): Data race freedom is a complete compile-time proof for safe code.**

**Acceptance:** every test in the concurrency category, including adversarial captures of non-Sendable types into `spawn { }`, produces the correct diagnostic or compiles correctly.

### G-7 — Unsafe audit

**Phase 1 (immediate): Inventory every `unsafe { }` block.**
- Grep the OSS compiler and stdlib for every `unsafe { }` block.
- For each block, write a one-paragraph soundness argument explaining why the block is sound: what invariants hold, why the code respects them, what happens if the invariants are violated.
- Store the inventory in `docs/unsafe-audit.md`.

**Phase 2 (short-term): Property test per unsafe block.**
- For each unsafe block, write a property test that exercises the invariant the unsafe code depends on.
- The property test must pass before the unsafe block is considered audited.

**Phase 3 (v1.0 gate): No new unsafe block is accepted into the compiler or stdlib without a soundness comment and a property test.**
- Enforced by code review and by `nuc audit` / `nuc gov` (when the governance rod is in place).
- New `@policy(NoUnsafe)` from the governance rod becomes default for new rod modules.

**Acceptance:** every unsafe block in the OSS tree has a soundness argument; every soundness argument has a property test; the inventory is complete and signed.

### G-8 — Conditional-branch divergence in ownership/borrow

**Phase 1 (immediate): Test set targeting OWN-VAL-5 and BR-6.**
- Build a structured set of fixtures: every shape of conditional move/borrow divergence (move in if-only, move in else-only, move in both arms, borrow in if + use after, borrow in else + use after, mut borrow in if + shared in else, etc.).
- Determine which the checker handles correctly, which it rejects too conservatively, which it accepts when it shouldn't.

**Phase 2 (short-term): Fix the inconsistencies.**
- Where the checker rejects too conservatively, refine to accept sound code.
- Where the checker accepts unsound code, tighten to reject.

**Phase 3 (v1.0 gate): Every shape in the test set produces the expected diagnostic.**

### G-9 — FFI raw-pointer arguments and lengths are not bounds-checked

**Phase 1 (immediate): Document at every FFI boundary.**
- Every `extern fn` that takes a length parameter documents the trust assumption.
- Every rod that wraps such an FFI provides a bounds-checked wrapper.

**Phase 2 (short-term): `extern fn` annotations for length-pairs.**
- Add syntax: `extern fn foo(p: i64, len: i64 [bounds_for: p])` — the compiler emits a runtime bounds check before the call.

### G-10 — Cross-function ownership/borrow inference

This is the long-term goal that BR-7 Phase 3 progresses toward. No separate closure plan; tracked through G-2 phases.

### G-11 — MS-7 stress test set

**Phase 1 (immediate): Add stress tests.**
- `tests/lang/uninit_*` test set covering every code path that could read an uninitialized value.
- Each test confirms either the compiler rejects the code or the value is provably initialized at the read.

---

## 3.4. Phasing summary

| Phase | What lands | Gap closures |
|---|---|---|
| **Phase 1 (immediate)** | Diagnostic warnings, documentation, audits, test sets | G-1 P1, G-2 P1, G-3 P1, G-4 P1, G-5 P1, G-6 P1, G-7 P1, G-8 P1, G-9 P1, G-11 |
| **Phase 2 (short-term)** | Runtime instrumentation, simple lifetime checking, Sendable propagation, unsafe property tests | G-1 P2, G-2 P2, G-3 P2, G-4 P2, G-5 P2, G-6 P2, G-7 P2, G-8 P2, G-9 P2 |
| **Phase 3 (medium-term)** | Cross-function borrow inference, idempotent free, wrapper-struct collections | G-2 P3, G-3 P3, G-4 P3 |
| **Phase 4 (v1.0 gate)** | Default-on auto-drop, default-on lifetime enforcement, complete data-race proof | G-1 P3, G-2 P4, G-3 P4, G-5 P3, G-6 P3, G-7 P3, G-8 P3 |

**v1.0 release gate:** Phases 1-4 complete for G-1 through G-7. G-8 through G-11 in at least Phase 2. The Rust-style memory-safety claim is honestly defensible at v1.0 only after this gate clears.

---

## 3.5. Validation tie-in

This RFC creates the closures. The validation protocol verifies them. Specifically:

- Every closure phase produces test fixtures that become part of the validation evidence package for the affected feature ring.
- The `memory_safety` block in each per-feature evidence record references the gap-closure phase that backed each MS-N guarantee. Example: `"ms1_use_after_free": { "result": "PASS", "evidence_ref": "...", "closure_phase": "G-1 Phase 2" }`.
- The `borrow` block references the BR-N validation backed by gap-closure phase. Example: `"br7_lifetime_param_runtime_safe": { "result": "PASS", "evidence_ref": "...", "closure_phase": "G-2 Phase 1 (warning-only)" }`.
- A QA reviewer can trace any memory-safety or borrow claim back to the closure phase that backs it.

When a closure phase advances (e.g. G-2 from Phase 1 warning-only to Phase 2 simple checking), the affected evidence records must be re-validated under the stronger guarantee.

---

## 3.6. Open questions for the main agent

1. **Should `#[auto_drop]` Phase 1 land alongside the governance rod, or independently?** The two efforts are unrelated but both touch the same compiler attribute infrastructure. Recommendation: independently; auto-drop is a memory-safety closure with higher priority.
2. **Does the runtime instrumentation in G-3 Phase 2 / G-4 Phase 2 use the existing `NUC_TRACE_ALLOC=1` machinery, or a separate flag?** Recommendation: extend `NUC_TRACE_ALLOC=1` rather than create a parallel system.
3. **What's the migration story for existing user code that uses `<'a>` annotations as documentation?** Phase 1 warning-only mode is the answer for the language, but third-party user code may have lifetime annotations that won't pass Phase 4 enforcement. Recommendation: a migration tool (`nuc migrate-lifetimes`) that flags the questionable patterns.
4. **What's the scope of the unsafe audit (G-7)?** Just the compiler + rod stdlib? Or include all example programs and tests? Recommendation: compiler + rod stdlib + any code that ships in OSS as an example. User-written code is out of scope.
5. **Should idempotent-free (G-4 Phase 3) be the default in release builds, or panic-on-double-free?** Idempotent is safer (no crash from a benign bug); panic is more honest (the bug is surfaced immediately). Recommendation: panic in debug, idempotent in release.

---

## 3.7. Effort sizing (no time estimates per user policy)

- **G-1 Phase 1 (auto-drop opt-in stabilization):** MEDIUM
- **G-1 Phase 2 (Drop trait + scope-exit insertion):** LARGE
- **G-1 Phase 3 (default-on auto-drop):** MEDIUM
- **G-2 Phase 1 (lifetime warning):** SMALL
- **G-2 Phase 2 (simple lifetime checking):** LARGE
- **G-2 Phase 3 (cross-function inference):** LARGE
- **G-2 Phase 4 (warning → error):** SMALL
- **G-3 Phase 1-2 (docs + runtime instrumentation):** MEDIUM
- **G-3 Phase 3-4 (wrapper-struct migration):** MEDIUM-LARGE
- **G-4 Phase 1-3 (OWN-012 + idempotent free):** MEDIUM
- **G-5 Phase 1-3 (FFI nullable):** MEDIUM
- **G-6 Phase 1-3 (Sendable hardening):** MEDIUM-LARGE
- **G-7 Phase 1-3 (unsafe audit):** MEDIUM (most cost is in writing the soundness comments)
- **G-8 Phase 1-3 (conditional divergence):** SMALL-MEDIUM
- **G-9, G-10, G-11:** SMALL each

Total effort: comparable to two major language milestones (e.g. v0.5 + v0.6 combined). Phasing distributes this load.

---

# Part IV — Disposition

## 4.1. Document path

```
C:\Users\JoeWe\Desktop\Nucleor_Memory_Safety_Borrow_Ownership_Gap_Analysis_and_RFC_2026-05-04.md
```

## 4.2. What this document is

A single combined gap analysis + RFC. Part I defines the terms. Part II inventories the gaps. Part III proposes the closure plan in phases, with v1.0 release-gate criteria. Part IV is this disposition page.

The document is suitable for handing directly to the main agent for integration into the Nucleor build spine and for promotion to a real RFC under `docs/rfcs/`.

## 4.3. What this document is NOT

- It is not a validation protocol. The validation protocol is a separate document, drafted from the foundation inventory the previous Sonnet subagent produced. The two documents reference each other but do different work.
- It is not a substitute for the v1.0 milestone planning. The phases here populate the milestone backlog; the actual milestone scoping is the main agent's call.
- It is not a substitute for `tests/err/_unimplemented/README.md`. That file tracks what's quarantined; this RFC tracks what should be unquarantined and how.

## 4.4. Recommended integration order

1. Read this document end-to-end (target audience: the main agent on the build spine, plus you for review).
2. Promote Phase 1 of every gap to the active punchlist. Phase 1 is mostly documentation, audits, and warning-only diagnostics — all low-risk, all immediate signal.
3. Schedule Phase 2 of G-1 (Drop trait) and G-2 (simple lifetime checking) as the next two major milestones. These are the load-bearing closures.
4. Update `tests/err/_unimplemented/README.md` to reference the corresponding gap IDs as each closure phase lands.
5. Once the governance rod (separate spec) is in place, use it to record the closure status in evidence packages.

---

*End of document.*
