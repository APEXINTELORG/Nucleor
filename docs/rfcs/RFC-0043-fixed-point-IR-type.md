# RFC-0043 — Restore `fixed<I, F>` Fixed-Point IR Type

**Status:** Draft (drift restoration — V1.12)
**Date:** 2026-05-03
**Predecessor:** Nucleor V2 had this as a tracked IR type with width tracking through BinOp; OSS regressed to parse-only sugar (line 8764 of `compiler/nucleor_s1_compiler.nr` collapses `fixed<*>` to bare `i64`).

## Motivation

Adopters porting embedded / DSP / financial Rust code use `fixed<I, F>` for predictable fractional arithmetic without f32/f64 rounding hazards. Common cases: Q15.16 audio sample math, Q1.31 control-loop accumulators, monetary `fixed<60, 4>` (cents-class precision without IEEE binary-fraction error).

Today the type parses but every value collapses to `i64`, so:
- Width-checked overflow is impossible.
- Fractional-bit semantics aren't enforced (`fixed<8, 8>` and `fixed<16, 16>` are indistinguishable at the IR level).
- Mixed `fixed<I,F> + i64` operations silently widen.

## Design

Introduce `IrTypeFixed { i_bits: u8, f_bits: u8, signed: bool }` as a first-class IR type alongside the existing scalar types. Width tracking propagates through:

- **Parse:** `fixed<I, F>` and `ufixed<I, F>` both accepted; carries through to AST type-string.
- **Type-check:** `IrTypeFixed` carried in `__type_<binding>` sym entries. Mixed-arith with `i*` requires explicit `as` cast (mirrors today's strict integer-arith policy).
- **BinOp lowering:** add/sub track the wider operand width. Multiply doubles fractional bits (`fixed<8,8> * fixed<8,8>` → `fixed<16,16>` intermediate, then truncate-or-saturate per `OverflowMode` to declared result type). Divide is the inverse.
- **Codegen:** a `fixed<I, F>` value occupies an `i(I+F)` storage slot at runtime; the compiler emits `shl`/`shr`/`mul` sequences scaled to the fractional point.

Runtime helpers: `__nucleor_fixed_mul_qIF` (signed/unsigned variants per bit width), `__nucleor_fixed_div_qIF`, `__nucleor_fixed_to_i64`, `__nucleor_fixed_from_i64`. Code-gen emits inline `shl/shr` for add/sub (no helper needed).

## Bound + corner cases

- Allowed widths: `I + F ≤ 64`. Wider rejected at parse with clean diag pointing at adopter `bigint`-style arbitrary precision.
- Saturating-multiply behavior controlled by the surrounding overflow-mode block (per RFC-0044 once shipped) — `wrapping{}` truncates, `saturating{}` clamps, `checked{}` panics on overflow.
- Conversion `fixed<I,F> as i64`: drops fractional bits (truncate-toward-zero, matching Rust integer cast semantics).

## Cost

~300 LOC compiler-side (parse + type-check + binop lowering + codegen). 6 runtime helpers. One fixture per arithmetic op (~12 fixtures total).

## Hot-path risk

Low. The fixed-point type only fires when the type annotation is present — the i64 hot path is untouched.

## Forward-roadmap interactions

- Pairs with **RFC-0044 per-BinOp `OverflowMode`** for principled mul/div overflow handling.
- Sister to **RFC-0049 memory-space type tags** — both add structured data to type-string slots.

## Closure criteria

- `let q: fixed<8, 8> = 1.5;` and `let r: fixed<8, 8> = q * q;` round-trip with declared semantics.
- Cross-width arith (`fixed<8,8> + fixed<16,8>`) requires explicit `as` cast — clean diag if missing.
- Round-2 self-host fixed-point holds.
