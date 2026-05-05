// v0.8.210 stdlib/rods/math.nr first test coverage.
//
// Integer math utilities (abs, min, max, clamp, pow_int,
// sqrt_int, gcd, lcm, is_even, is_odd). Pre-v0.8.210: zero
// coverage on the standalone rod.
//
// Locks four invariants — including the NUM-G2 abs/pow_int
// overflow guards (v0.8.80/81) which silent-miscompute under
// NUCLEOR_INT_STRICT_INTRIN=0:
//
//   1. **Basic abs/min/max/clamp** — abs(-7)=7, min(3,5)=3,
//      max(3,5)=5, clamp(10, 0, 5)=5, clamp(-1, 0, 5)=0.
//   2. **pow_int(2, 10) == 1024** — exponent identity (also
//      exercises the NUM-G2 overflow detection path).
//   3. **gcd(12, 18) == 6** — Euclidean algorithm.
//   4. **lcm(4, 6) == 12; is_even(4)==1; is_odd(7)==1; sqrt_int(16)==4** —
//      integer-derivative chain (lcm uses gcd internally).
//
// Expected: rc=0.

import "stdlib/rods/math.nr"

fn check_basics() -> i64 {
    if math_abs(0 - 7) != 7 { return 1; };
    if math_min(3, 5) != 3 { return 2; };
    if math_max(3, 5) != 5 { return 4; };
    if math_clamp(10, 0, 5) != 5 { return 8; };
    if math_clamp(0 - 1, 0, 5) != 0 { return 16; };
    if math_clamp(3, 0, 5) != 3 { return 32; };
    return 0;
}

fn check_pow_int() -> i64 {
    if math_pow_int(2, 10) != 1024 { return 64; };
    if math_pow_int(3, 4) != 81 { return 128; };
    if math_pow_int(0 - 2, 3) != (0 - 8) { return 256; };
    return 0;
}

fn check_gcd() -> i64 {
    if math_gcd(12, 18) != 6 { return 512; };
    if math_gcd(17, 13) != 1 { return 1024; };
    if math_gcd(0, 5) != 5 { return 2048; };
    return 0;
}

fn check_chain() -> i64 {
    if math_lcm(4, 6) != 12 { return 4096; };
    if math_is_even(4) != 1 { return 8192; };
    if math_is_even(7) != 0 { return 16384; };
    if math_is_odd(7) != 1 { return 32768; };
    if math_sqrt_int(16) != 4 { return 65536; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_basics();
    fails = fails + check_pow_int();
    fails = fails + check_gcd();
    fails = fails + check_chain();
    return fails;
}
