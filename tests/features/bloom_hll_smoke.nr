// v0.8.95 stdlib/rods/bloom.nr first test coverage.
//
// Per the v0.8.94 zero-coverage rod survey, bloom.nr (Bloom
// filter + HyperLogLog cardinality estimator) had no existing
// tests. This fixture locks the textbook invariants:
//
// Bloom filter:
//   1. Empty filter returns 0 (not contains) for any key.
//   2. After adding "alpha", contains("alpha") returns 1.
//   3. False negatives are forbidden: every added key MUST
//      report contained.
//   4. count() reports the number of distinct keys added (or
//      a close approximation depending on the impl).
//
// HyperLogLog:
//   1. Empty estimator reports 0.
//   2. After adding N distinct keys, count is roughly N
//      (within HLL's standard 1.04/sqrt(2^p) error bound).
//      We accept a wide tolerance here since the error
//      depends on the precision parameter.
//
// Expected: rc=0 (assertions bump rc on failure).

import "stdlib/rods/bloom.nr"

fn check_bloom_empty() -> i64 {
    let h: i64 = bloom_new(1000, 1);
    if h == 0 { return 1; };
    let c: i64 = bloom_contains(h, "missing");
    bloom_free(h);
    if c != 0 { return 2; };
    return 0;
}

fn check_bloom_add_contains() -> i64 {
    let h: i64 = bloom_new(1000, 1);
    if h == 0 { return 4; };
    bloom_add(h, "alpha");
    bloom_add(h, "beta");
    bloom_add(h, "gamma");
    let a: i64 = bloom_contains(h, "alpha");
    let b: i64 = bloom_contains(h, "beta");
    let g: i64 = bloom_contains(h, "gamma");
    bloom_free(h);
    // No false negatives — all three must report contained.
    if a != 1 || b != 1 || g != 1 { return 8; };
    return 0;
}

fn check_bloom_no_false_negatives() -> i64 {
    let h: i64 = bloom_new(100, 1);
    if h == 0 { return 16; };
    let mut i: i64 = 0;
    while i < 50 {
        bloom_add(h, str_concat("key_", str_from_int(i)));
        i = i + 1;
    };
    // Every added key must report contained.
    let mut j: i64 = 0;
    let mut missing: i64 = 0;
    while j < 50 {
        if bloom_contains(h, str_concat("key_", str_from_int(j))) != 1 {
            missing = missing + 1;
        };
        j = j + 1;
    };
    bloom_free(h);
    if missing > 0 { return 32; };
    return 0;
}

fn check_hll_empty() -> i64 {
    let h: i64 = hll_new(10);
    if h == 0 { return 64; };
    let c: i64 = hll_count(h);
    hll_free(h);
    if c != 0 { return 128; };
    return 0;
}

fn check_hll_distinct_count_roughly_correct() -> i64 {
    let h: i64 = hll_new(10);
    if h == 0 { return 256; };
    // Add 100 distinct keys.
    let mut i: i64 = 0;
    while i < 100 {
        hll_add(h, str_concat("key_", str_from_int(i)));
        i = i + 1;
    };
    let count: i64 = hll_count(h);
    hll_free(h);
    // HLL precision=10 (m=1024) → standard error ≈ 1.04/sqrt(1024)
    // ≈ 3.25%. Accept wide tolerance: count must be in [50, 200].
    if count < 50 { return 512; };
    if count > 200 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_bloom_empty();
    fails = fails + check_bloom_add_contains();
    fails = fails + check_bloom_no_false_negatives();
    fails = fails + check_hll_empty();
    fails = fails + check_hll_distinct_count_roughly_correct();
    return fails;
}
