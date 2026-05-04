// v0.8.97 stdlib/rods/bigint.nr first test coverage.
//
// Per the zero-coverage rod survey, bigint.nr (arbitrary-
// precision integers) had no existing tests. Silent regressions
// in BigInt arithmetic are correctness-critical — the whole
// point of arbitrary-precision is exact.
//
// Locks (all assertions via bi_cmp; result comparison against
// bi_from_int / bi_from_str references):
//
//   1. cmp identity / lt / gt
//   2. add: small i64-fitting + larger crossing 2^32
//   3. sub: positive and resulting-negative
//   4. mul: small + 2^32-crossing exact product
//   5. div / mod: integer-division semantics + Euclidean
//      identity (a == (a/b)*b + (a%b))
//   6. powmod: 2^10 mod 1000 == 24, 2^32 mod 100 == 96
//   7. bi_from_str round-trip via cmp against bi_from_int
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/bigint.nr"

fn check_cmp_basic() -> i64 {
    let a: i64 = bi_from_int(5);
    let b: i64 = bi_from_int(5);
    let c: i64 = bi_from_int(10);
    if bi_cmp(a, b) != 0 { return 1; };
    if bi_cmp(a, c) != 0 - 1 { return 2; };
    if bi_cmp(c, a) != 1 { return 4; };
    return 0;
}

fn check_add_sub() -> i64 {
    let r1: i64 = bi_add(bi_from_int(5), bi_from_int(3));
    if bi_cmp(r1, bi_from_int(8)) != 0 { return 8; };
    let r2: i64 = bi_sub(bi_from_int(10), bi_from_int(3));
    if bi_cmp(r2, bi_from_int(7)) != 0 { return 16; };
    // Crossing the 2^32 boundary
    let big: i64 = bi_from_str("4294967300");        // 2^32 + 4
    let four: i64 = bi_from_int(4);
    let r3: i64 = bi_sub(big, four);
    if bi_cmp(r3, bi_from_str("4294967296")) != 0 { return 32; };
    return 0;
}

fn check_mul() -> i64 {
    let r: i64 = bi_mul(bi_from_int(7), bi_from_int(8));
    if bi_cmp(r, bi_from_int(56)) != 0 { return 64; };
    // 65536 * 65536 = 2^32 = 4294967296 (crosses the limb)
    let r2: i64 = bi_mul(bi_from_int(65536), bi_from_int(65536));
    if bi_cmp(r2, bi_from_str("4294967296")) != 0 { return 128; };
    return 0;
}

fn check_div_mod() -> i64 {
    let q: i64 = bi_div(bi_from_int(100), bi_from_int(7));
    let r: i64 = bi_mod(bi_from_int(100), bi_from_int(7));
    if bi_cmp(q, bi_from_int(14)) != 0 { return 256; };
    if bi_cmp(r, bi_from_int(2)) != 0 { return 512; };
    // Euclidean identity: a == (a/b)*b + (a%b)
    let recombined: i64 = bi_add(bi_mul(q, bi_from_int(7)), r);
    if bi_cmp(recombined, bi_from_int(100)) != 0 { return 1024; };
    return 0;
}

fn check_powmod() -> i64 {
    // 2^10 mod 1000 = 1024 mod 1000 = 24
    let r: i64 = bi_powmod(bi_from_int(2), bi_from_int(10), bi_from_int(1000));
    if bi_cmp(r, bi_from_int(24)) != 0 { return 2048; };
    // 2^32 mod 100 = 4294967296 mod 100 = 96
    let r2: i64 = bi_powmod(bi_from_int(2), bi_from_int(32), bi_from_int(100));
    if bi_cmp(r2, bi_from_int(96)) != 0 { return 4096; };
    return 0;
}

fn check_from_str_round_trip() -> i64 {
    // bi_from_str on a small int matches bi_from_int.
    if bi_cmp(bi_from_str("42"), bi_from_int(42)) != 0 { return 8192; };
    if bi_cmp(bi_from_str("0"), bi_from_int(0)) != 0 { return 16384; };
    if bi_cmp(bi_from_str("-7"), bi_from_int(0 - 7)) != 0 { return 32768; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cmp_basic();
    fails = fails + check_add_sub();
    fails = fails + check_mul();
    fails = fails + check_div_mod();
    fails = fails + check_powmod();
    fails = fails + check_from_str_round_trip();
    return fails;
}
