# RFC: Numerics — Overflow Semantics

## Summary

Integer overflow in Nucleor wraps modulo 2^width by default
(matches C / Rust release-mode). Per-op intrinsics
(`wrapping_<op>`, `saturating_<op>`, `checked_<op>`) opt into
explicit overflow handling.

## Default behavior

```nucleor
let a: u8 = 250;
let b: u8 = 10;
let c: u8 = a + b;   // c = 4 (260 mod 256)
```

`a + b` evaluates at i64 register width; the
narrow_via_as hook on the let-binding inserts
`__nucleor_as_u8(a + b)` which masks to 8 bits — equivalent to
mod-256 wrap.

Float operations follow IEEE-754 (no special handling needed).

## Per-op overflow modes

For any integer width T ∈ {i8, i16, i32, i64, u8, u16, u32, u64}:

```nucleor
wrapping_add_T(a, b)   // mod 2^width — always defined
wrapping_sub_T(a, b)
wrapping_mul_T(a, b)

saturating_add_T(a, b) // clamp at T::MAX or T::MIN
saturating_sub_T(a, b)
saturating_mul_T(a, b)

checked_add_T(a, b)    // wrapped value + sets overflow flag
checked_sub_T(a, b)    // query via checked_overflow_flag()
checked_mul_T(a, b)
```

## checked_* overflow flag pattern

```nucleor
let _ = checked_add_u8(250, 10);
let of: i64 = checked_overflow_flag();
if of == 1 {
    // handle overflow
}
```

The side-channel pattern matches the existing i64 convention.
T1.2 will replace it with `Result<T, OverflowError>` once sum
types with payloads ship.

## Float overflow

Float ops follow IEEE-754:
- Overflow → `+inf` / `-inf`
- Division by zero → `+inf` / `-inf` / `NaN` per IEEE rules
- 0.0 / 0.0 → `NaN`
- NaN propagates through subsequent ops

## Casting and overflow

`f64 as i32`, `f32 as i32` etc. saturate (Rust semantics):
- value > i32::MAX → i32::MAX
- value < i32::MIN → i32::MIN
- NaN → 0

See `numerics_cast.md` for the full cast matrix.

## Future: `#[overflow(wrap | trap | saturate)]` attribute

A future attribute can change the default `+ - *` behavior on a per-fn
or per-module basis:

```nucleor
#[overflow(trap)]
fn safety_critical(x: i32, y: i32) -> i32 {
    return x + y;   // panics on overflow instead of wrapping
}
```

Currently the only way to get trap semantics is to call
`checked_<op>_T` and check the flag. The attribute is sugar.
