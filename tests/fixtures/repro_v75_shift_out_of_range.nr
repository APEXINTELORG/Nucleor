// repro_v75_shift_out_of_range.nr — v0.4.75 NUM-008.
// Pre-fix `1 << 64` returned 1 (LLVM `shl i64 X, 64` is poison;
// downstream code observed an undefined value, which for the const
// case folded to 1). `1 << -1` returned i64::MIN
// (-9223372036854775808) for the same reason. Adopters writing
// canonical Rust got overflow_left_shift (debug) or wrapping
// behavior (release) — either way explicit. Nucleor's i64-everywhere
// ABI fixes the operand width at 64.
//
// v0.4.75 promotes literal-int shift-out-of-range to NUM-008
// (already reserved in RFC-0015 / v0.2.319 expansion). Walks
// through unary-minus on the RHS so `1 << -1` is also caught.
//
// EXPECT: build fails with NUM-008 (msg contains "out of range").

fn main() -> i64 {
    let x: i64 = 1 << 64;
    println!("{}", x);
    return 0;
}
