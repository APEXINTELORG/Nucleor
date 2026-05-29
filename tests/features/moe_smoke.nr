// v0.8.214 stdlib/rods/moe.nr first test coverage.
//
// Mixture-of-Experts routing — top-K gating, dispatch/combine,
// load-balance tracker. Pre-v0.8.214: zero coverage on the
// standalone rod.
//
// Setup: 2 tokens, 3 experts, K=2. Logits row 0 = [10, 0, 0]
// (dominant expert 0); row 1 = [0, 10, 0] (dominant expert 1).
//
// Locks four invariants:
//
//   1. Top-K winner is the largest logit — token 0 picks
//      expert 0 first; token 1 picks expert 1 first.
//   2. Dominant-winner weight ≈ 1 per token — for logits
//      [10,0,0] expert 0 wins by 22000:1; after K=2 renormalize
//      its weight is ≈ 1.
//   3. Indices are within [0, n_experts) — no garbage IDs.
//   4. Balance tracker non-zero CV after uneven dispatch —
//      moe_balance_update on indices [0,0,1,1] (skewed) gives
//      non-zero load CV (vs. n_experts=3 uniform).
//
// Expected: rc=0.

import "stdlib/rods/moe.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn build_logits() -> i64 {
    let mut logits: Vec<i64> = Vec::new();
    // Token 0: expert 0 dominant
    logits.push(f64_to_bits(10.0));
    logits.push(f64_to_bits(0.0));
    logits.push(f64_to_bits(0.0));
    // Token 1: expert 1 dominant
    logits.push(f64_to_bits(0.0));
    logits.push(f64_to_bits(10.0));
    logits.push(f64_to_bits(0.0));
    return logits;
}

fn check_topk_winner() -> i64 {
    let logits: i64 = build_logits();
    let routing: i64 = moe_topk_gate(logits, 2, 3, 2);
    let indices: i64 = moe_route_indices(routing);
    // token 0's first pick
    let i00: i64 = vec_get(indices, 0);
    if i00 != 0 { return 1; };
    // token 1's first pick (offset 2 because K=2)
    let i10: i64 = vec_get(indices, 2);
    if i10 != 1 { return 2; };
    return 0;
}

fn check_weights_dominant_winner() -> i64 {
    // Token 0's first weight (highest-logit expert) is ≈ 1.
    // Renormalized over K=2; since logits=[10,0,0] make expert 0
    // dominant by a 22000:1 margin, w00 ≈ 1.0.
    let logits: i64 = build_logits();
    let routing: i64 = moe_topk_gate(logits, 2, 3, 2);
    let weights: i64 = moe_route_weights(routing);
    let w00: i64 = vec_get(weights, 0);
    let f: f64 = f64_from_bits(w00);
    if f < 0.99 { return 4; };
    if f > 1.01 { return 4; };
    return 0;
}

fn check_indices_in_range() -> i64 {
    let logits: i64 = build_logits();
    let routing: i64 = moe_topk_gate(logits, 2, 3, 2);
    let indices: i64 = moe_route_indices(routing);
    let n: i64 = vec_len(indices);
    let mut i: i64 = 0;
    while i < n {
        let v: i64 = vec_get(indices, i);
        if v < 0 { return 8; };
        if v >= 3 { return 16; };
        i = i + 1;
    };
    return 0;
}

fn check_balance_cv_nonzero() -> i64 {
    let lb: i64 = moe_balance_new(3);
    let mut idx: Vec<i64> = Vec::new();
    // skewed load: 4 tokens × K=1 all going to expert 0 then 1
    idx.push(0); idx.push(0); idx.push(1); idx.push(1);
    moe_balance_update(lb, idx, 4, 1);
    let cv: i64 = moe_balance_cv(lb);
    let cvf: f64 = f64_from_bits(cv);
    let abs_cvf: f64 = if cvf < 0.0 { 0.0 - cvf } else { cvf };
    if abs_cvf < 1e-9 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_topk_winner();
    fails = fails + check_weights_dominant_winner();
    fails = fails + check_indices_in_range();
    fails = fails + check_balance_cv_nonzero();
    return fails;
}
