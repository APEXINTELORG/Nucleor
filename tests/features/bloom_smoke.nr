// v0.8.134 stdlib/rods/bloom.nr first test coverage.
//
// Bloom filter + HyperLogLog — probabilistic membership and
// cardinality. Pre-v0.8.134: zero coverage.
//
// Locks four invariants:
//   1. Empty filter: contains() returns 0 for any key.
//   2. After add(k), contains(k) == 1 (no false negatives — the
//      defining Bloom-filter property).
//   3. count() tracks insertions exactly.
//   4. HLL count for 100 distinct keys is within ±20% (HLL p=10
//      typical error ~3%, ±20% is generous so flake-free).
//
// Expected: rc=0.

import "stdlib/rods/bloom.nr"

fn check_empty_no_member() -> i64 {
    let fp: i64 = f64_to_bits(0.01);
    let b: i64 = bloom_new(100, fp);
    if bloom_contains(b, "anything") != 0 { bloom_free(b); return 1; };
    if bloom_contains(b, "") != 0 { bloom_free(b); return 2; };
    bloom_free(b);
    return 0;
}

fn check_no_false_negatives() -> i64 {
    let fp: i64 = f64_to_bits(0.01);
    let b: i64 = bloom_new(100, fp);
    bloom_add(b, "alpha");
    bloom_add(b, "beta");
    bloom_add(b, "gamma");
    if bloom_contains(b, "alpha") != 1 { bloom_free(b); return 4; };
    if bloom_contains(b, "beta") != 1 { bloom_free(b); return 8; };
    if bloom_contains(b, "gamma") != 1 { bloom_free(b); return 16; };
    bloom_free(b);
    return 0;
}

fn check_count() -> i64 {
    let fp: i64 = f64_to_bits(0.01);
    let b: i64 = bloom_new(100, fp);
    if bloom_count(b) != 0 { bloom_free(b); return 32; };
    bloom_add(b, "k1");
    bloom_add(b, "k2");
    bloom_add(b, "k3");
    if bloom_count(b) != 3 { bloom_free(b); return 64; };
    bloom_free(b);
    return 0;
}

fn check_hll_cardinality() -> i64 {
    // hll_count returns f64 bit-cast as i64 (per nuc_hll_count signature).
    let h: i64 = hll_new(10);
    let mut i: i64 = 0;
    while i < 100 {
        let mut s: str = "key_";
        s = str_concat(s, int_to_str(i));
        hll_add(h, s);
        i = i + 1;
    };
    let est_bits: i64 = hll_count(h);
    hll_free(h);
    let est: f64 = f64_from_bits(est_bits);
    // ±20% of 100: 80..120 (HLL p=10 typical error ~3%, this is generous)
    if est < 80.0 { return 128; };
    if est > 120.0 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_no_member();
    fails = fails + check_no_false_negatives();
    fails = fails + check_count();
    fails = fails + check_hll_cardinality();
    return fails;
}
