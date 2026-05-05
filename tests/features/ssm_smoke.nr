// v0.8.227 stdlib/rods/ssm.nr first test coverage.
//
// State Space Models — Mamba selective scan, SSD chunked,
// RWKV WKV, xLSTM cell, ZOH discretization. Pre-v0.8.227:
// zero coverage on the standalone rod.
//
// Locks four ZOH-discretization invariants on
// `ssm_discretize_zoh`. The other four ops (selective_scan,
// SSD, RWKV, xLSTM) need careful tensor setup; deferred.
//
//   1. **Output length is 2*N** — Ab and Bb packed in a single
//      Vec.
//   2. **Ab[i] = exp(dt * A[i])** — for diagonal A=[-1, -2],
//      dt=1: Ab = [exp(-1), exp(-2)].
//   3. **A=0 fallback uses Bb = dt * B** — for A=[0, 0],
//      B=[1, 2], dt=0.5: Bb = [0.5, 1.0].
//   4. **A=0 fallback gives Ab = 1** — exp(0) = 1.
//
// Expected: rc=0.

import "stdlib/rods/ssm.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_output_length() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(0.0 - 1.0));
    a.push(f64_to_bits(0.0 - 2.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(1.0));
    b.push(f64_to_bits(1.0));
    let r: i64 = ssm_discretize_zoh(a, b, f64_to_bits(1.0), 2);
    if vec_len(r) != 4 { return 1; };
    return 0;
}

fn check_ab_exp_formula() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(0.0 - 1.0));
    a.push(f64_to_bits(0.0 - 2.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(1.0));
    b.push(f64_to_bits(1.0));
    let r: i64 = ssm_discretize_zoh(a, b, f64_to_bits(1.0), 2);
    // Ab[0] = exp(-1) ≈ 0.36788
    if close(vec_get(r, 0), f64_to_bits(0.36787944117144233), 1e-9) != 1 { return 2; };
    // Ab[1] = exp(-2) ≈ 0.13534
    if close(vec_get(r, 1), f64_to_bits(0.1353352832366127), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_a_zero_bb_fallback() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(0.0));
    a.push(f64_to_bits(0.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(1.0));
    b.push(f64_to_bits(2.0));
    let r: i64 = ssm_discretize_zoh(a, b, f64_to_bits(0.5), 2);
    // Bb[0] = dt * B[0] = 0.5
    if close(vec_get(r, 2), f64_to_bits(0.5), 1e-9) != 1 { return 8; };
    // Bb[1] = dt * B[1] = 1.0
    if close(vec_get(r, 3), f64_to_bits(1.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn check_a_zero_ab_one() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(0.0));
    a.push(f64_to_bits(0.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(1.0));
    b.push(f64_to_bits(2.0));
    let r: i64 = ssm_discretize_zoh(a, b, f64_to_bits(0.5), 2);
    // Ab = exp(0 * dt) = 1.0
    if close(vec_get(r, 0), f64_to_bits(1.0), 1e-12) != 1 { return 32; };
    if close(vec_get(r, 1), f64_to_bits(1.0), 1e-12) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_output_length();
    fails = fails + check_ab_exp_formula();
    fails = fails + check_a_zero_bb_fallback();
    fails = fails + check_a_zero_ab_one();
    return fails;
}
