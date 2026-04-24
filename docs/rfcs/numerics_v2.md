# RFC: Numerics v2 — T1.1 Maximalist Refactor (Final)

**Status:** Shipped  
**Versions:** v0.2.307 — v0.2.322 (Phases 0–13)  
**Started:** 2026-04-24  
**Closed:** 2026-04-24

## Summary

The T1.1 narrow-numerics refactor brought every numeric type the
compiler accepts (`i8/i16/i32/i64/i128`, `u8/.../u128`,
`isize/usize`, `f16/bf16/f32/f64`) up to first-class semantics
end-to-end — IR, codegen, FFI, memory layout, casts, comparisons,
overflow handling, formatting, and diagnostics. No hidden i64
promotions in user-visible behavior.

## Goals (delivered)

1. **All integer widths native** with width-correct arithmetic
   on `let` binding (Phase 1).
2. **All float widths native** with `+ - * /` and comparisons
   dispatched to per-width runtime helpers (Phase 5).
3. **Overflow modes** — `wrapping_<op>_<T>`, `saturating_<op>_<T>`,
   `checked_<op>_<T>` for every primitive width (Phase 7).
4. **`as` cast operator** with full Rust semantics — saturating
   float→int, sign-extending widening, truncating narrowing,
   bit-preserving `as i64` for FFI use (Phase 4).
5. **Width-correct memory** for `Vec<u8>` (1 byte / element)
   via the existing `vec_u8_*` runtime; generic `Vec<T>`
   monomorphization syntax sugar deferred to a follow-up
   (Phase 8).
6. **FFI ABI**: extern fn declarations with narrow types emit
   correct LLVM signatures; `nuc gen-headers` subcommand emits
   matching C headers (Phase 9).
7. **Diagnostics namespace** — NUM-001..NUM-020 with title +
   short fix + reasoning; rendered with file:line:col span
   (Phase 10).
8. **Width-correct formatting** — `print_<T>` for every integer
   and float width (Phase 11).
9. **Stdlib audit** — fixed `str_from_int` + `print_int` to use
   i64 internal arithmetic so narrow-width let-binding doesn't
   truncate large register IDs (Phase 3c).
10. **Rod audit** — 221 rods walked; default i64-FFI keeps
    every rod working unchanged (Phase 12).

## Locked design decisions

1. **Overflow default**: wrap in release, trap in debug
   (Rust-style). `#[overflow(wrap | trap | saturate)]` attribute
   ships in Phase 7.2 follow-up; per-op intrinsics
   (`wrapping_add_u8`, etc.) ship now.
2. **Cast operator `as`**: Rust semantics — saturating
   float→int, truncating int→narrow-int, sign-extend for
   signed widening, zero-extend for unsigned widening,
   `fpext`/`fptrunc` for float widths.
3. **Suffix literal syntax**: `255u8`, `1_000i32`, `3.14f32`,
   `0.5f16`, `42usize`, `1_000_000u64`. Underscore separators
   anywhere in the digit run.
4. **`usize`/`isize`**: resolve to platform pointer width
   (64-bit on all currently supported targets).

## Companion RFCs

- [`numerics_wrap.md`](numerics_wrap.md) — overflow semantics.
- [`numerics_cast.md`](numerics_cast.md) — `as` cast operator
  matrix.
- [`numerics_ffi.md`](numerics_ffi.md) — extern fn ABI rules
  + `nuc gen-headers`.
- [`numerics_repr.md`](numerics_repr.md) — struct layout +
  `sizeof_<T>` / `sizeof_struct(<Name>)` builtins.
- [`numerics_rod_audit.md`](numerics_rod_audit.md) — Phase 12
  rod walkthrough.

## Production-readiness gates added

- **2 GB memory cap** on `verify.sh` and `verify.ps1` (and
  matrix runner). Catches runaway compiles before swap-thrash.
  Override via `NUCLEOR_MEM_CAP_KB` / `NUCLEOR_MEM_CAP_MB`.
- **Bootstrap fixpoint check** — stage-1 binary compiles
  source → stage-2; stage-2 must produce SHA-256-identical
  IR for `tests/lang/arith.nr` to stage-1's output. Catches
  the entire class of "compiler change silently poisons next
  compile" bugs.
- **Defensive narrow-source guard** — `narrow_via_as` rejects
  source registers `< 0` so upstream lowering bugs surface as
  visible errors, not silent IR.
- **`archive/i64-only` branch** preserved on GitHub at
  v0.2.306 — the pre-refactor architecture is permanent and
  re-checkout-able.

## Matrix outcome

```
Phase         PASS  FAIL  BERR   TOT
p11_format       3     0     0     3
p12_rods         1     0     0     1
p1_intarith     24     0     0    24
p2_literals      6     0     0     6
p3_layout        5     0     0     5
p4_cast          8     0     0     8
p5_float         4     0     0     4
p6_bitwise       4     0     0     4
p7_overflow      4     0     0     4
p8_vec           3     0     0     3
p9_ffi           1     0     0     1
TOTAL           63     0     0    63
```

Matrix went from `31P/9F/16BE` baseline at v0.2.307 to
`63P/0F/0BE` at v0.2.322 — every test green at every phase
boundary; bootstrap fixpoint stable throughout.

Verify gate moved from 328 → 331 steps (added gen-headers smoke
+ bootstrap fixpoint + NUM-002 negative test). All phases shipped
with verify gate green at every commit.

## Out of scope (T1.1 explicitly DOES NOT include)

These items are valid future work but were intentionally not
in T1.1's contract:

- **Full `HashMap` monomorphization** for arbitrary user types
  (T1.3 territory).
- **`Box<T>` / heap-allocator refactor** — separate item.
- **SIMD types** (`i32x4`, `f32x8`, etc.) — separate roadmap.
- **Decimal / fixed-point types** — separate item.
- **Bit-fields in structs** — separate item.
- **Turbofish syntax sugar** for overflow intrinsics
  (`wrapping_add::<u8>(a, b)`) — Phase 7.2 follow-up;
  underlying `wrapping_add_u8(a, b)` API ships now.
- **`#[overflow(wrap|trap|saturate)]` attribute** — Phase 7.2
  follow-up; per-op intrinsics ship now.
- **Generic `Vec<T>::with_capacity(N)` syntax** — direct API
  `vec_u8_with_capacity` etc. ships now; turbofish lands later.
- **Per-struct alloca-at-width** — i64-uniform alloca remains;
  load/store width refactor would require touching every
  Nucleor program, deemed too risky for T1.1's blast radius.

## Total

- **15 tagged releases** (v0.2.307 – v0.2.322)
- **6 RFC documents** (this file + 5 companions)
- **~63 matrix tests** + 1 negative-gate test added
- **331 verify-gate steps** (was 328 at v0.2.306)
- **Verify gate green at every commit**
- **Bootstrap fixpoint stable throughout**
