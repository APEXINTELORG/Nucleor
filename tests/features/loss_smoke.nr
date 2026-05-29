// v0.8.204 stdlib/rods/loss.nr first test coverage.
//
// Neural-network loss functions (cross-entropy, KL, MSE, Huber,
// focal, InfoNCE, cosine-similarity matrix). Pre-v0.8.204:
// zero coverage on the standalone rod.
//
// Locks four textbook loss-function invariants:
//
//   1. MSE of identical vectors == 0 — pred==target → 0.
//   2. MSE([1,2,3], [2,3,4]) == 1.0 — mean of (1²+1²+1²)/3.
//   3. KL(p||p) == 0 — KL of a distribution against itself.
//   4. CE on uniform logits + target=0 == log(n) —
//      logits=[0,0,0] gives p=1/3, loss = -log(1/3) = log(3).
//
// Expected: rc=0.

import "stdlib/rods/loss.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_mse_identical_zero() -> i64 {
    let mut p: Vec<i64> = Vec::new();
    p.push(f64_to_bits(1.0));
    p.push(f64_to_bits(2.0));
    p.push(f64_to_bits(3.0));
    let mut t: Vec<i64> = Vec::new();
    t.push(f64_to_bits(1.0));
    t.push(f64_to_bits(2.0));
    t.push(f64_to_bits(3.0));
    let l: i64 = loss_mse(p, t);
    if close(l, f64_to_bits(0.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_mse_unit_offset() -> i64 {
    let mut p: Vec<i64> = Vec::new();
    p.push(f64_to_bits(1.0));
    p.push(f64_to_bits(2.0));
    p.push(f64_to_bits(3.0));
    let mut t: Vec<i64> = Vec::new();
    t.push(f64_to_bits(2.0));
    t.push(f64_to_bits(3.0));
    t.push(f64_to_bits(4.0));
    let l: i64 = loss_mse(p, t);
    if close(l, f64_to_bits(1.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_kl_self_zero() -> i64 {
    let mut p: Vec<i64> = Vec::new();
    p.push(f64_to_bits(0.5));
    p.push(f64_to_bits(0.3));
    p.push(f64_to_bits(0.2));
    let mut q: Vec<i64> = Vec::new();
    q.push(f64_to_bits(0.5));
    q.push(f64_to_bits(0.3));
    q.push(f64_to_bits(0.2));
    let l: i64 = loss_kl(p, q);
    if close(l, f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_ce_uniform_logits() -> i64 {
    // logits = [0, 0, 0], target=0 → loss = log(3) ≈ 1.0986122886681098
    let mut logits: Vec<i64> = Vec::new();
    logits.push(f64_to_bits(0.0));
    logits.push(f64_to_bits(0.0));
    logits.push(f64_to_bits(0.0));
    let l: i64 = loss_ce(logits, 0);
    if close(l, f64_to_bits(1.0986122886681098), 1e-6) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mse_identical_zero();
    fails = fails + check_mse_unit_offset();
    fails = fails + check_kl_self_zero();
    fails = fails + check_ce_uniform_logits();
    return fails;
}
