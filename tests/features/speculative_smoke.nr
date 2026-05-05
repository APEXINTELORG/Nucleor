// v0.8.227 stdlib/rods/speculative.nr first test coverage.
//
// Speculative decoding for LLM inference — verify draft tokens
// against target distribution, build draft trees, sample with
// temperature + top-k. Pre-v0.8.227: zero coverage on the
// standalone rod.
//
// Locks four sampling invariants:
//
//   1. **Top-K=1 returns argmax** — for logits [10, 0, 0] with
//      top_k=1, the only non-zero probability mass is on
//      token 0; sample MUST return 0.
//   2. **Top-K=1 picks middle index when middle is largest** —
//      logits [0, 10, 0] → 1.
//   3. **Top-K=1 picks last index when last is largest** —
//      logits [0, 0, 10] → 2.
//   4. **Seeded RNG is reproducible** — spec_seed(42) twice
//      followed by sampling from the same uniform-ish logits
//      with top_k=2 returns the same token both times.
//
// Verify and build_tree need careful tensor setup; deferred.
//
// Expected: rc=0.

import "stdlib/rods/speculative.nr"

fn build_logits_argmax_at(n: i64, peak: i64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        if i == peak { v.push(f64_to_bits(10.0)); }
        else { v.push(f64_to_bits(0.0)); };
        i = i + 1;
    };
    return v;
}

fn check_top1_argmax_first() -> i64 {
    let logits: i64 = build_logits_argmax_at(3, 0);
    let t: i64 = spec_sample(logits, f64_to_bits(1.0), 1);
    if t != 0 { return 1; };
    return 0;
}

fn check_top1_argmax_middle() -> i64 {
    let logits: i64 = build_logits_argmax_at(3, 1);
    let t: i64 = spec_sample(logits, f64_to_bits(1.0), 1);
    if t != 1 { return 2; };
    return 0;
}

fn check_top1_argmax_last() -> i64 {
    let logits: i64 = build_logits_argmax_at(3, 2);
    let t: i64 = spec_sample(logits, f64_to_bits(1.0), 1);
    if t != 2 { return 4; };
    return 0;
}

fn check_seed_reproducible() -> i64 {
    let mut logits: Vec<i64> = Vec::new();
    logits.push(f64_to_bits(1.0));
    logits.push(f64_to_bits(1.0));
    logits.push(f64_to_bits(1.0));

    spec_seed(42);
    let a: i64 = spec_sample(logits, f64_to_bits(1.0), 2);

    spec_seed(42);
    let b: i64 = spec_sample(logits, f64_to_bits(1.0), 2);

    if a != b { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_top1_argmax_first();
    fails = fails + check_top1_argmax_middle();
    fails = fails + check_top1_argmax_last();
    fails = fails + check_seed_reproducible();
    return fails;
}
