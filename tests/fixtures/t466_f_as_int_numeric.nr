// t466_f_as_int_numeric.nr -- v0.3.211 NUC-FEEDBACK runtime safety
// + Rust-semantic alignment.
//
// Pre-v0.3.211 the cast lowering for `f64 as i64` (and `f64 as u64`,
// `f32 as i64`, `f32 as u64`) fell through to the bit-cast preserving
// `as_i64` / `as_u64` helpers. That made `1.5_f64 as i64` return the
// i64 bit pattern of 1.5_f64 (≈4607182418800017408) instead of the
// numeric truncation result `1` -- a silent miscompute when adopters
// copy-pasted Rust code expecting numeric `as` semantics.
//
// Fix: f-source / i64-or-u64 target now dispatches to the saturating
// numeric-truncation helper (matches Rust `as`).
//
// Bit-pattern transit (the thing the old behavior was useful for) now
// uses the explicit reinterpret surface: f64_to_bits(x), f32_to_bits(x).
// This makes intent local to the call site instead of relying on the
// quirk.

fn main() -> i64 {
    let a: f64 = 1.5;
    let b: f64 = 3.7;
    let c: f64 = -2.9;
    println!("{}", a as i64);   // 1 (was: huge bit pattern)
    println!("{}", b as i64);   // 3
    println!("{}", c as i64);   // -2 (truncate toward zero)

    let f: f32 = 7.6 as f32;
    println!("{}", f as i64);   // 7 (was: bit-pattern junk)
    println!("{}", f as u64);   // 7

    // Saturation at i64 bounds (constructed via repeated multiplication
    // since the lexer doesn't support scientific notation literals).
    let big: f64 = 1000000.0;
    let bigger: f64 = big * big;       // 1e12
    let huge: f64 = bigger * bigger;   // 1e24, exceeds i64::MAX
    println!("{}", huge as i64);       // 9223372036854775807 (i64::MAX, saturated)

    // Bit-pattern transit (old behavior path) requires explicit call
    let g: f64 = 0.5;
    let bits: i64 = f64_to_bits(g);
    let back: f64 = f64_from_bits(bits);
    println!("{}", back);       // 0.5

    return 0;
}
