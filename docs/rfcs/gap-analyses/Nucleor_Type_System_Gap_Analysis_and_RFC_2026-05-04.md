# Nucleor — Type System, Generics, and Trait Machinery: Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Companion docs:** `Nucleor_Memory_Safety_Borrow_Ownership_Gap_Analysis_and_RFC_2026-05-04.md` (parallel pillar — currently under active fix)
**Disposition:** No file writes were made into `Nucleor_OSS` while drafting this.

---

# Part I — Definitions

## 1.1. The type-system pillar

The type system is the substrate every other safety claim rests on: ownership reasons about which *typed* binding owns which *typed* value; effects annotate *typed* function signatures; capability tokens are *typed* values that the type system tracks. If the type system silently coerces, erases types at boundaries, or accepts annotations it doesn't enforce, every claim built on top of it is hollow.

This document covers eleven type-system dimensions:
1. Primitive types and ABI consistency
2. Generics
3. Traits, impls, derives
4. Type inference
5. Lifetime parameters
6. The `as` cast operator
7. `?` propagation and `From`/`Into`
8. Width-suffixed integer literals
9. Type confusion / soundness holes
10. Tuple structs and tuple types
11. `Option`/`Result` as user-typed generics

## 1.2. Eleven type-system validation categories (TS-1 through TS-11)

Maps 1:1 to the dimensions. Each is graded for "what's claimed" vs "what's enforced."

---

# Part II — Gap Analysis

## 2.1. Stated goals (from RFCs)

- **RFC-0015** (numeric types): "Replace the current 'everything is an `i64` slot' model with distinct numeric types at every storage and computation point." Promises full width set, NUM-001..005 diagnostics, `Vec<u8>` with honest storage, no implicit conversion.
- **RFC-0024** (generics): Shipped at v0.4.182 — `fn id<T>`, `struct Pair<A,B>`, `enum Maybe<T>`, generic-over-generic, bound checking via TYP-025.
- **RFC-0026** (trait objects): Static dispatch via `Type::method()` ships; `dyn Trait` deferred to v0.5+.
- **RFC-0027** (lifetimes): Parser-only; borrow checker does NOT enforce.
- **RFC-0016** (Result/Option): Generic enum monomorphization shipped at v0.4.186.

## 2.2. The eighteen gaps

### T-1 — IR width-tagged ops not shipped — **CRITICAL**
The compiler still emits uniform `i64` for all arithmetic, allocas, loads, and stores regardless of declared numeric type. `let x: u8 = 255; let y: u8 = x + 1;` computes at 64-bit, wraps only to i64 bounds, not u8 bounds. RFC-0015 phase 3 plan exists; v0.4.199 execution attempt was reverted because it caused 1.4× hot compile regression. The single biggest gap between language promise and machine reality. Concrete failure: `let a: u8 = 200; let b: u8 = 200; let c: u8 = a + b;` — current `c` holds 400 in an i64 slot; no wrap, no trap (unless NUCLEOR_INT_STRICT_INTRIN traps at i64 overflow, which is the wrong width).

### T-2 — Lifetime parameters not enforced — **CRITICAL**
Same as BR-7 in the memory-safety RFC. Listed here for completeness because lifetime is a type-system concern as well as a borrow concern. `impl<'a> Foo<'a>` halts entirely — parser defect on top of the enforcement gap.

### T-3 — `char` is not a distinct type — **CRITICAL**
`types_compatible` silently accepts any integer type as equivalent to `char`. A `char` binding can receive a raw `i64` without error and vice versa. `as char` cast routes to `as_u32` with no Unicode validation (no rejection of surrogate range or out-of-range codepoints). Concrete failure: `let c: char = 0xFFFFFFFF as char; let s: str = char_to_str(c);` — produces invalid UTF-8 with no compile-time signal.

### T-4 — Empty type = compatible soundness hole — **CRITICAL**
`types_compatible` returns 1 when either expected or actual type is the empty string. Source-scan type inference (`infer_var_type_from_source`) returns `""` when it fails — which happens routinely in complex expressions, across function boundaries, or in closures. A type-checker failure silently becomes "compatible," allowing any mistyped expression through.

### T-5 — Generic monomorphization is type erasure — **HIGH**
The compiler emits one binary body for all instantiations of a generic function. `T` is erased to i64. `min::<f64>(1.5, 2.5)` and `min::<i64>(1, 2)` share one body. Works by accident for simple pass-through; **silently miscomputes for any operation that is type-dependent** (an integer comparison on f64 bit patterns gives wrong ordering for negatives). User-visible claim: generics work. Reality: they work for handle-passing, not for arithmetic.

### T-6 — Trait bound enforcement is incomplete — **HIGH**
TYP-025 fires at call sites but: (a) `where` bounds on struct/impl/enum decls are silently skipped (only fn decls parse them); (b) the unique-impl restriction means adding a second impl for any type breaks dispatch; (c) compound bounds `<T: A + B>` record both `?A` and `?B` independently, no conjunction enforcement.

### T-7 — `#[derive(PartialEq)]` does not wire `==` — **HIGH**
`#[derive(PartialEq)]` generates `<Type>__derived_eq(a, b) -> i64` but does NOT make `a == b` dispatch to it. Adopters who write `derive(PartialEq)` and then use `==` get TYP-011 (pointer-compare diagnostic) or fall through to raw i64 comparison. **Silently wrong for the user's intent.**

### T-8 — FFI boundary erases all types — **HIGH**
`extern fn` calls bypass bounds-check insertion. Every parameter type collapses to i64/ptr at the FFI boundary. Documented as known but advisory only — no enforcement. This is the same root as MS-5 (FFI null) but type-erasure-wide, not just nullable returns.

### T-9 — Type inference is source-text scanning — **HIGH**
Not Hindley-Milner or bidirectional. Three-tier fallback: (1) explicit annotations (required on `let`), (2) regex-based source-text scan to find `let <name>: <type>`, (3) pattern-binding scan for `Some(x)`/`Ok(x)`. Can give wrong answers (name shadowing collisions), silently degrade to `""` (which passes type checks via T-4), or give stale results from caches.

### T-10 — `Option`/`Result` element-type propagation through `vec_get` — **HIGH**
RFC-0024 Phase 4 (Vec<T> element type propagation through `vec_get`/`vec_first`/`vec_last`/`vec_pop`) is unshipped. The `vec_element_type_is_legacy_cell` check for `Vec<i32>` is still live. `let v: Vec<f64> = ...; let x = v[0];` may return type `i64` to the type-checker. Downstream uses get either type-mismatch errors or silent miscompute (the bits ARE f64; if used in integer arithmetic, misinterpreted).

### T-11 — `where` clauses on structs/impls/enums silently skipped — **MEDIUM**
`skip_where_clause` is called at struct/impl/enum sites without extracting bounds. Only fn decls use `parse_where_clause_into_gparams`. `struct Sorted<T> where T: Ord { items: Vec<T> }` parses cleanly but `T: Ord` is discarded.

### T-12 — Tuple type / let-destructure absent — **MEDIUM**
Tuple types `(T1, T2)` not first-class. `let (a, b) = (5, 7)` rejected. Tuple-struct patterns in match arms rejected. Significant ergonomics gap from Rust.

### T-13 — Associated types absent — **MEDIUM**
`type Item;` in trait bodies halts with parse error. Blocks Iterator, FromIterator, GAT. Workaround (extra generic param on the trait) changes API surface.

### T-14 — `dyn Trait` / vtable absent — **MEDIUM**
Deferred to v0.5+. Static dispatch only. Heterogeneous collections impossible without external workarounds.

### T-15 — Generic trait-bound dispatch requires unique impl — **MEDIUM**
v0.6 fix works only when there's exactly one concrete impl for the method in the entire program. Two impls of the same trait for different types cause TYP-007 even when the call site is unambiguous. Conservative restriction blocks practical polymorphic patterns.

### T-16 — Closure parameter types not inferred — **MEDIUM**
Closures typed as `i64`. No `Fn`/`FnMut`/`FnOnce` inference. Closure parameters have no type annotations and types are not propagated.

### T-17 — `#[repr(C)]` not propagated — **LOW**
`#[repr(C)]` parses but not propagated to the struct AST node. `sizeof_struct` reports `field_count × 8` regardless of C-layout intent. FFI-facing structs get wrong layout computations.

### T-18 — `impl From<X> for Y` string-keyed, not first-class — **LOW**
From/Into via string-keyed registry lookup, not proper generic trait. Two types with same string name (possible across modules where mangling is incomplete) can return wrong impl. Flat Vec linear scan.

## 2.3. Cross-cutting risks

- **Identifier-vs-heap aliasing (alias-bypass class).** Same root as MS-1/MS-2/MS-6. Type checker uses string names; IR is i64-everywhere. Type-inference failure → `""` → "compatible" → any i64 flows where any named type is expected.
- **Soundness via `unsafe { }` blocks.** Currently semantically equivalent to a regular block (Nucleor has no checked operations to opt out of yet). When safe-mode restrictions arrive in v1, existing `unsafe {}` code was written without unsafe discipline — migration hazard.
- **FFI boundary type erasure.** Compounds T-8. `Vec<i32>` legacy-cell convention for Option/Result still live — a Vec declared `Vec<i32>` may be carrying [tag, payload] pairs.
- **"Syntax accepted but not enforced" trust hazard (BR-7 class generalized).** Lifetime annotations, struct `where` clauses, most `#[derive]` macros (Eq/Hash/Default/Copy/Ord/PartialOrd silently dropped with DERIVE-001 warning), `impl<'a>` (halts), `?Sized`, `const` generic params — adopters porting Rust code believe safety is in place. It is not.
- **Comptime evaluation soundness.** `const` items evaluate at compile time using same i64-everywhere arithmetic. RFC-0034 compile-time params are parsed and skipped — `fn make_array<const N: usize>()` compiles with `N` erased.

---

# Part III — RFC: Closing the Type-System Gaps

## 3.1. Goals

1. Make the type system **honestly enforce** what its syntax declares.
2. Close the four CRITICAL gaps before any v1.0 release.
3. Close the seven HIGH gaps before v1.0 or document them as explicit limitations with diagnostic warnings.
4. Track MEDIUM gaps as v1.x roadmap items.
5. **No regressions in shipped behavior**: phased rollouts with warning-only modes precede error-mode flips.

## 3.2. Non-goals

- Full Rust-grade type system (HRTB, GAT, const generics) — these are post-v1.
- Replacing the i64-everywhere ABI wholesale — incremental width tagging in IR is the goal, not ABI replacement.

## 3.3. Closure plan, by gap

### T-1 — IR width-tagged ops

**Phase 1 (immediate):** Diagnose mixed-width arithmetic where the result silently exceeds the declared width. `NUM-005` (silent width overflow) fires as a warning when the compiler can prove the declared width is insufficient.

**Phase 2 (short-term):** Lift narrow-width arithmetic into LLVM iN ops at the boundary of `wrapping {}` / `saturating {}` / `checked {}` blocks. This is the v0.4.199 work, redesigned to avoid the 1.4× regression — likely by emitting iN ops only inside the explicit-mode blocks, not pervasively.

**Phase 3 (medium-term):** Width-tagged storage. `let x: u8` allocates one byte (or pads to a slot but tracks the type tag). Loads sign-extend or zero-extend per the declared signedness. Stores trap if the stored value exceeds the declared width.

**Phase 4 (v1.0 gate):** Width-correct arithmetic for all typed integer operations. The `i64` slot becomes an implementation detail, not a semantic guarantee.

**Acceptance:** RFC-0015 examples pass; `let a: u8 = 200; let b: u8 = 200; let c: u8 = a + b;` traps under default strict mode.

### T-2 — Lifetime parameters

Already covered in the memory-safety RFC §3.3 G-2. Cross-reference; no separate plan here.

### T-3 — `char` is not a distinct type

**Phase 1 (immediate):** Remove `char`-to-any-integer compatibility wildcard from `types_compatible`. Cast `i64 as char` becomes explicit and validated.

**Phase 2 (short-term):** Validate Unicode scalar value range on `as char`: reject surrogates (U+D800–U+DFFF), reject codepoints > U+10FFFF. New diagnostic `TYP-026` (invalid char codepoint).

**Phase 3 (v1.0 gate):** `char` is a distinct type at the IR level (4-byte or u32 slot), not aliasable with integers without explicit cast.

**Acceptance:** Mixing `char` and `i64` without explicit cast is a compile error; `as char` validates Unicode.

### T-4 — Empty-type compatibility soundness hole

**Phase 1 (immediate):** Remove the empty-string-is-compatible fallthrough from `types_compatible`. When inference fails, the compiler returns `TYP-027` (type inference failed; explicit annotation required) rather than silently passing.

**Phase 2 (short-term):** Improve type inference so the failure rate of `infer_var_type_from_source` drops dramatically. (See T-9.)

**Acceptance:** No code paths in the compiler treat empty type as compatible. Inference failures produce explicit diagnostics.

### T-5 — Generic monomorphization

**Phase 1 (immediate):** Document the type-erasure limitation prominently. Every generic function header gets a doc comment noting "T is erased to i64; type-dependent operations may miscompute for non-i64 types."

**Phase 2 (short-term):** Detect type-dependent operations inside generic bodies (arithmetic on `T`, comparison ordering on `T`, format strings using `T`) and emit `TYP-028` (type-dependent op in erased generic — recommend bound or specialization).

**Phase 3 (medium-term):** Per-call-site monomorphization for generic functions where any parameter or return is `f32`/`f64`/struct-with-non-i64-fields. Other instantiations continue to share the erased body.

**Phase 4 (v1.0 gate):** Full per-call-site monomorphization. Type erasure is no longer the implementation strategy.

**Acceptance:** `min::<f64>(...)` and `min::<i64>(...)` produce correct results regardless of negative values, NaN, etc.

### T-6 — Trait bound enforcement

**Phase 1 (immediate):** `where` clauses on struct/impl/enum decls parsed and stored, even if not yet enforced. `TYP-029` warning when a `where` bound is parsed but not checked.

**Phase 2 (short-term):** Conjunction enforcement for `<T: A + B>` — verify all bounds together at the call site, not independently.

**Phase 3 (v1.0 gate):** Multi-impl trait dispatch — relax the unique-impl restriction. Use the standard Rust resolution rules (most-specific impl wins; ambiguity is a clear error with both candidates listed).

**Acceptance:** Polymorphic code with multiple trait impls compiles and dispatches correctly.

### T-7 — `#[derive(PartialEq)]` does not wire `==`

**Phase 1 (immediate):** `==`/`!=` operators on a struct that has `#[derive(PartialEq)]` dispatch to `<Type>__derived_eq` automatically. Implemented via the trait registry.

**Phase 2 (short-term):** Same for `#[derive(Eq)]`, `#[derive(Hash)]`, `#[derive(Clone)]`, `#[derive(Default)]`. Each derive macro produces a fully-wired implementation, not just a generated helper.

**Phase 3 (v1.0 gate):** Full derive macro suite — Eq, Hash, Default, Copy, Clone, PartialEq, Debug. DERIVE-001 ("silently dropped") never fires for these.

**Acceptance:** `if a == b { ... }` on a `#[derive(PartialEq)]` struct dispatches to the derived helper without user intervention.

### T-8 — FFI boundary type erasure

Cross-references MS-5 (FFI null) from the memory-safety RFC. Additional type-system work:

**Phase 1 (immediate):** Diagnostic `TYP-030` (FFI boundary type widening) when an `extern fn` returns `i64` but is declared to return a more specific type — alerts the user that the type system cannot verify.

**Phase 2 (short-term):** `extern fn ... -> Vec<u8>` etc. — typed returns at the FFI boundary that the wrapper layer enforces. The compiler inserts a runtime tag check at the boundary if the wrapper doesn't.

**Phase 3 (v1.0 gate):** All built-in rod FFI boundaries use typed wrappers, not raw i64.

### T-9 — Type inference is source-text scanning

**Phase 1 (immediate):** Document the limitation. Adopters know annotations are usually required.

**Phase 2 (short-term):** Replace the regex-based source scan with an AST-based bidirectional inference pass. Single-statement scope only; cross-statement inference deferred.

**Phase 3 (medium-term):** Cross-statement inference within a single function body. Hindley-Milner-light without let-polymorphism.

**Phase 4 (v1.0 gate):** Inference quality matches Rust for the common cases (let with non-generic RHS, closures with annotated params).

### T-10 — Vec element-type propagation

**Phase 1 (immediate):** RFC-0024 Phase 4 work — propagate the element type of `Vec<T>` through `vec_get`, `vec_first`, `vec_last`, `vec_pop`. Type checker uses the propagated type instead of the legacy-cell fallback.

**Phase 2 (short-term):** Same for `HashMap`, `BTreeMap`, `HashSet`, `BTreeSet`, `VecDeque`. All collection-element accessors are type-correct.

**Phase 3 (v1.0 gate):** `Vec<i32>` legacy-cell convention is removed; Option/Result use proper generic enum representation.

### T-11 through T-18 — MEDIUM and LOW gaps

Each gets a Phase 1 documentation pass + Phase 2-3 implementation in priority order:
- T-11 (where on structs): Phase 2 — parse and enforce
- T-12 (tuples): Phase 3 — first-class tuple types
- T-13 (associated types): Phase 3 — at minimum for Iterator
- T-14 (dyn Trait): Phase 2 — already on v0.5+ roadmap
- T-15 (multi-impl dispatch): see T-6 Phase 3
- T-16 (closure inference): Phase 3 — Fn/FnMut/FnOnce traits
- T-17 (`#[repr(C)]`): Phase 1 — propagate to struct AST and use in sizeof_struct
- T-18 (From/Into registry): Phase 3 — proper trait dispatch with mangled names

## 3.4. Phasing summary

| Phase | What lands | Gap closures |
|---|---|---|
| **Phase 1** | Documentation, warning diagnostics, immediate soundness fixes (T-3 wildcard removal, T-4 empty-type fix), `==` wiring for PartialEq | T-1 P1, T-3 P1, T-4 P1, T-5 P1, T-6 P1, T-7 P1, T-8 P1, T-9 P1, T-10 P1, T-17 |
| **Phase 2** | Width-correct arith inside explicit blocks, char Unicode validation, type-dependent op detection in generics, AST-based inference | T-1 P2, T-3 P2, T-5 P2, T-6 P2, T-7 P2, T-8 P2, T-9 P2, T-10 P2, T-11, T-14 |
| **Phase 3** | Width-tagged storage, per-call monomorphization for non-i64, cross-statement inference, tuples, associated types | T-1 P3, T-5 P3, T-9 P3, T-12, T-13, T-16, T-18 |
| **Phase 4 (v1.0 gate)** | Width-correct everywhere, char distinct, multi-impl dispatch, full derive suite, no legacy Vec<i32> cell | T-1 P4, T-3 P3, T-5 P4, T-6 P3, T-7 P3, T-8 P3, T-9 P4, T-10 P3 |

**v1.0 release gate:** Phases 1-4 complete for T-1 through T-10. Phases 1-2 minimum for T-11 through T-18.

## 3.5. Validation tie-in

The validation protocol's behavioral-correctness pillar references this RFC. Each Ring 0 type-system feature carries an evidence record with a `type_system` block referencing the closure phase that backs the claim.

## 3.6. Open questions for the main agent

1. Does the v0.4.199 width-correct attempt's revert reasoning still hold, or has the optimizer landscape changed? Recommend a fresh prototype before committing to T-1 Phase 2 design.
2. Should char validation reject all surrogates or just lone surrogates? Recommendation: reject all surrogates outside paired use; valid Nucleor strings are scalar-value sequences.
3. For T-5 Phase 3, is per-call monomorphization gated on f32/f64/struct, or unconditional? Recommendation: gated, to bound code-size growth.
4. For T-7, does `#[derive(Debug)]` block on having a stable `Display`/`Debug` trait first? Recommendation: yes — derive depends on the trait being defined first.

## 3.7. Effort sizing

- T-1 P1-P4: LARGE total (this is multi-quarter work)
- T-3, T-4: SMALL each (single-pass fixes)
- T-5 P1-P4: LARGE total
- T-6, T-7, T-9 P1-P3: MEDIUM each
- T-10: MEDIUM
- T-11 through T-18: SMALL-MEDIUM each

Total: comparable to the memory-safety closure plan in scope, with T-1 alone being the largest single piece.

---

# Part IV — Disposition

**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md`

This is one of 13 per-competency Gap Analysis + RFC documents. Companion docs (memory safety done; concurrency, effects, RT in this batch; nine more pending).

*End of document.*
