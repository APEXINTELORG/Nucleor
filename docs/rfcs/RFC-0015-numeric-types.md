# RFC-0015 — Numeric Types Refactor

| Field | Value |
|---|---|
| **Number** | 0015 |
| **Title** | Numeric Types — distinct `i8/i16/i32/i64`, `u8/u16/u32/u64`, `f32/f64`, `usize/isize`, `bf16`, `f16`, `f8e4m3`, `f8e5m2` |
| **Status** | Draft |
| **Author** | Joseph Wescott + Claude |
| **Created** | 2026-04-22 |
| **Target release** | v0.2.0 |
| **Depends on** | none — foundational |

---

## 1. Summary

Replace the current "everything is an `i64` slot" model with distinct
numeric types at every storage and computation point.

```nucleor
let a: u8  = 255;
let b: u8  = a + 1;          // wraps to 0 in release; traps in debug
let c: i32 = -2147483648;
let d: u64 = 0xDEADBEEFCAFE;
let e: f32 = 3.14;
let f: f64 = 3.14159265358979;
let g: usize = arr.len();    // platform pointer-width unsigned
let h: bf16 = 0.5;           // ML era
let q: f8e4m3 = 1.0;         // FP8 quantization

// Mixed-width arithmetic requires explicit cast
let mixed: i64 = c as i64 + (d as i64);   // OK
let bad:   i64 = c + d;                    // ERROR: i32 + u64
```

**Foundational refactor.** Everything else in the v0.2-v0.7 roadmap
depends on having honest numeric types. Today's `Vec<f64>` actually
stores `i64` slots holding f64 bit-patterns; you can't have `u8`
buffers, `f32` ML weights, or `usize` indices.

---

## 2. Motivation

### 2.1 What's wrong today

- `Vec<u8>` doesn't exist — you'd burn 8× memory.
- ML weights at `f32` need 50% of `f64` storage. Today: impossible.
- `bf16` / `f16` / FP8 — required for modern LLM inference; today
  unrepresentable.
- `usize` indices — required for portable array indexing across 32-/
  64-bit platforms.
- Allocator `Box<T, A>` from RFC-0002 needs to know `sizeof::<T>()`.
  Today: every `T` is 8 bytes regardless.
- `unit<T, dim>` from RFC-0005 needs distinct numeric storage to be
  useful.

### 2.2 What other languages do

| Language | Approach |
|---|---|
| **C** | All widths distinct; implicit conversions everywhere (footgun) |
| **C++** | C plus `std::int_least32_t` etc. (verbose) |
| **Rust** | All widths distinct; **no implicit conversions**; `as` for casts; `usize` for indices |
| **Go** | All widths distinct; `int`/`uint` is platform-default size; `int32`/`int64` explicit |
| **Zig** | All widths plus `i7`, `u3`, `f128`, etc. (arbitrary widths) |
| **Swift** | All widths plus protocols (`BinaryInteger`, `FloatingPoint`) |

**Decision: model on Rust.** Distinct, no implicit conversion,
explicit `as` cast, `usize`/`isize` for indices. Most honest, most
predictable, fits the safety story.

---

## 3. Design

### 3.1 The type set

| Category | Types |
|---|---|
| Signed integers | `i8`, `i16`, `i32`, `i64`, `i128`, `isize` |
| Unsigned integers | `u8`, `u16`, `u32`, `u64`, `u128`, `usize` |
| IEEE floats | `f16`, `f32`, `f64` |
| Brain float | `bf16` |
| FP8 | `f8e4m3`, `f8e5m2` |
| Bool | `bool` |
| Char | `char` (32-bit Unicode scalar value) |

`isize` / `usize` are pointer-width on the target (32-bit on 32-bit
targets, 64-bit on 64-bit targets).

### 3.2 No implicit conversion

`u8 + i32` is a type error. User must `as`-cast:

```nucleor
let a: u8 = 100;
let b: i32 = 1000;
let c: i32 = a as i32 + b;     // OK
let d: u8 = (b as u8) + a;     // OK, but b might overflow u8
```

### 3.3 Overflow modes

Three modes per build profile:

| Profile | `+`, `-`, `*` overflow |
|---|---|
| `debug` | Trap (panic) |
| `release` | Wrap (two's-complement) |
| `safe-release` | Trap |
| `cert` | Trap unless `assume!(no_overflow)` |

Always-defined behavior:
- `wrapping_add`, `wrapping_sub`, `wrapping_mul` — always wrap
- `checked_add`, `checked_sub`, `checked_mul` — return `Option<T>`
- `saturating_add`, `saturating_sub`, `saturating_mul` — clamp at min/max
- `overflowing_add` etc. — return `(T, bool)`

These are all **inherent methods** on every numeric type, so
`#[no_panic]` users have a clean API.

### 3.4 Float ops

f16/bf16/f8 are storage formats — most ops happen at f32 precision
for accuracy. Provide `mul_add` (FMA), `sqrt`, `sin`, `cos`, etc. on
each. Cast f16→f32 for computation, cast back for storage.

f8 ops require hardware (Hopper/Blackwell GPUs) or software emulation.
Software path is slow; document.

### 3.5 Casting rules

`as` casts are explicit, infallible, with defined behavior:

| From → To | Behavior |
|---|---|
| Integer → wider integer | Sign/zero-extend |
| Integer → narrower integer | Truncate (low bits) |
| Float → integer | Round toward zero, saturate at limits |
| Integer → float | Round to nearest |
| Float → narrower float | Round to nearest |
| Float → wider float | Exact |
| `char` → `u32` | Direct |
| `u32` → `char` | `try_from` returns `Result` (not all u32 are valid Unicode) |

`From` / `Into` traits available for all widening conversions
(infallible). `TryFrom` / `TryInto` for narrowing (returns `Result`).

### 3.6 Numeric literals

```nucleor
let a = 100;          // inferred from context, default i32
let b = 100u8;        // suffix
let c = 100i64;
let d = 0xFFu32;
let e = 0o777i32;
let f = 0b1010u8;
let g = 1_000_000;    // underscores ignored
let h = 3.14f32;
let i = 3.14;         // default f64
```

### 3.7 Composition with RFC-0001 attributes

`#[no_panic]` rejects naive `+` / `-` / `*` (per RFC-0004). Users
must use `wrapping_*` / `checked_*` / `saturating_*` or `assume!`-prove
no overflow.

### 3.8 Composition with RFC-0002 allocators

`Vec<T, A>` storage is `sizeof::<T>()` per element — finally honest.
A `Vec<u8>` of length 1024 occupies 1024 bytes, not 8192.

### 3.9 Diagnostics

| Code | Meaning |
|---|---|
| NUM-001 | Mixed-width arithmetic without cast |
| NUM-002 | Numeric literal out of range for declared type |
| NUM-003 | `as` cast loses precision (warning) |
| NUM-004 | f8/f16/bf16 op without hardware support (warning, falls back to f32) |
| NUM-005 | `usize`/`isize` mixed with explicit-width type |

---

## 4. Implementation

| Component | Change | LOC |
|---|---|---|
| Lexer | Numeric literal suffixes + underscores | ~200 |
| Type checker | Type lattice, no-implicit-conversion rule, cast inference | ~800 |
| IR | Width-tagged numeric ops | ~400 |
| Codegen | LLVM type per width | ~500 |
| Runtime (`*_rt.c`) | `printf`/`scanf`/arith helpers per width | ~600 |
| Stdlib | All 103 rods audited for width drift | ~1500 (rod-days) |
| Diagnostics | NUM-001…005 | ~300 |
| **Total** | | **~4300** |

The biggest item v0.2 ships. Can't be incremental — rod APIs change
breaking-ly.

### 4.1 Migration

This is **the breaking change** for v0.2. Every existing program
needs to declare numeric widths. We ship a `nuc fix --numeric` tool
that auto-converts likely-i64 declarations to `i64` and likely-f64 to
`f64`. Other widths require manual review.

---

## 5. Alternatives considered

- **Stay with i64-everywhere** — blocks every other RFC. Rejected.
- **Go-style implicit (default `int`)** — easier ergonomics but loses
  the safety story. Rejected.
- **Zig-style arbitrary-width (`i7`, `u3`)** — too ambitious for v0.2;
  defer.
- **Skip f8/f16/bf16** — blocks ML inference story. Ship them.

## 6. Open questions

1. `i128`/`u128` priority — Rust ships them; rare in robotics. Ship
   in v0.2 (cheap on x86, slower on 32-bit).
2. Default integer literal type — Rust uses inference; Go uses `int`.
   Recommend inference fallback to `i32`.
3. `usize` vs `u64` on 64-bit platforms — distinct types (Rust style)
   to keep portability.
4. Saturating-by-default for image ops? Recommend separate `Sat<T>`
   wrapper for those use cases.
5. f8 precision (e4m3 vs e5m2) — ship both per the SOTA spec
   (NVIDIA Hopper uses both).

## 7. Definition of done

- [ ] All 18 numeric types parse, type-check, codegen
- [ ] No-implicit-conversion rule enforced
- [ ] `as` cast tables per §3.5 implemented
- [ ] All `wrapping_*`, `checked_*`, `saturating_*`, `overflowing_*`
      methods on every integer type
- [ ] `nuc fix --numeric` migrates v0.1.x code with sensible defaults
- [ ] All 103 rods audited and ported
- [ ] Verify gate (101 → ~150 after audit) green
- [ ] CHANGELOG documents the breaking change + migration story

## 8. Future extensions

- Arbitrary widths (`i7`, `u3`) — Zig style, v1.0+
- SIMD vector types (`f32x4`, `i16x8`) — RFC-0033
- Decimal types (`d32`, `d64`, `d128`) for finance — community rod
- Rational / arbitrary-precision — community rod

## 9. Acceptance checklist

- [ ] Maintainer approves
- [ ] LOC budget ~4300 fits 6-week window
- [ ] Migration tool covers >90% of existing code
- [ ] Pitch survives ("honest numeric types — finally")
