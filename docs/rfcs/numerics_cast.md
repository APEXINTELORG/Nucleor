# RFC: Numerics — `as` Cast Operator Matrix

**Companion to:** `numerics_v2.md`
**Phase:** 4

## Summary

The `as` operator follows Rust semantics: saturating float→int,
truncating int→narrow-int, sign-extend for signed widening,
zero-extend for unsigned widening. With ONE exception: `as i64`
from a float source preserves the bit pattern (no truncation),
to support the i64-everywhere FFI contract.

## Cast matrix

### Integer → Integer (same or wider)

```
i8 → i16 / i32 / i64       sign-extend
u8 → i16 / i32 / i64       zero-extend (no sign bit to extend)
i16 → i32 / i64            sign-extend
u16 → i32 / i64            zero-extend
…
```

### Integer → Integer (narrower)

```
i32 → i8                   truncate to low 8 bits, sign-extend
u32 → u8                   truncate to low 8 bits (mod 256)
i64 → i32                  truncate, sign-extend
…
```

### Float → Integer (narrow target — i32 / u32)

```
f32 / f64 → i32            saturating: clamp to i32::MIN..i32::MAX
f32 / f64 → u32            saturating: clamp to 0..u32::MAX
                           NaN → 0
```

Implemented via `__nucleor_f32_to_i32`, `__nucleor_f32_to_u32`,
`__nucleor_f64_to_i32`, `__nucleor_f64_to_u32` runtime helpers.

### Float → i64 (special case — bit-preserving)

```
f32 / f64 → i64            BIT-PRESERVING (no truncation)
```

This is the exception. The Nucleor i64-everywhere ABI treats
i64 as a uniform value slot; many rod tests use
`f64_to_bits(x: f64) -> i64 { return x as i64; }` to extract a
bit pattern for FFI. To explicitly truncate float → i64, use
`(x as i32) as i64` or call the runtime helper directly:
`f64_to_i64(x)`.

### Float → Float

```
f32 → f64                  exact (widening)
f64 → f32                  rounds to nearest representable f32
                           (lossy for values needing >24 bits
                            mantissa precision, e.g. 0.1)
```

### Integer → Float

```
i8 / i16 / i32 / i64 → f32   converts numeric value (lossy for
                              values needing >23 bits mantissa)
u8 / u16 / u32 / u64 → f32   converts numeric value
i8 / i16 / i32 / i64 → f64   converts numeric value (exact for
                              up to 53-bit values)
u8 / u16 / u32 / u64 → f64   converts numeric value
```

### Other primitives

```
bool → i32 / i64           false=0, true=1
char → u32 / i32 / i64     Unicode scalar value
ptr → usize / isize        pointer-int round-trip safe
ptr → i32 / u32            LOSSY on 64-bit targets — diagnostic
                           NUM-012 fires
```

## Implementation

The cast operator (kind == 99 in the AST) lowers in
`compiler/nucleor_s1_compiler.nr` `lower_expr` `kind == 99`.
It calls `binop_float_type(inner_nid, sym)` to detect whether
the source is float-typed. Dispatch table:

| Source ftype | Target ftype | Helper                |
|--------------|--------------|------------------------|
| f32          | i32          | `f32_to_i32`           |
| f32          | u32          | `f32_to_u32`           |
| f32          | f64          | `f32_to_f64`           |
| f64          | i32          | `f64_to_i32`           |
| f64          | u32          | `f64_to_u32`           |
| f64          | f32          | `f64_to_f32`           |
| (int)        | f32          | `i64_to_f32`           |
| (int)        | f64          | `i64_to_f64`           |
| (any)        | i64          | falls through to `as_i64` (bit-preserve) |
| (int)        | (int)        | falls through to `as_<T>` mask |

## Diagnostic NUM-003 (precision loss)

For casts that may lose precision (e.g. `f64 as i32`), the
compiler emits NUM-003 as a warning. Suppress with
`#[allow(precision_loss)]` on the call site if intentional.
