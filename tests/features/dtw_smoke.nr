// v0.8.247 stdlib/rods/dtw.nr first test coverage.
//
// Dynamic Time Warping for n-dimensional time series. Pre-
// v0.8.247: zero coverage on the standalone rod. The
// algorithmic path needs raw double[] sequences (a_ptr / b_ptr);
// real DTW distance evaluation is deferred to dedicated
// time-series ships once the str/vec → raw-ptr bridge lands.
//
// Locks four bad-input invariants (the runtime null-checks
// both A and B and validates M/N/dim before allocating the DP
// table; this fixture verifies those guards):
//
//   1. Null pointers return 0 — both A and B null.
//   2. M=0 returns 0 — bad first sequence length.
//   3. N=0 returns 0 — bad second sequence length.
//   4. dim=0 returns 0 — bad point dimension.
//
// Expected: rc=0.

import "stdlib/rods/dtw.nr"

fn check_null_ptrs() -> i64 {
    let d: i64 = dtw_distance(0, 5, 0, 5, 2);
    if f64_from_bits(d) != 0.0 { return 1; };
    return 0;
}

fn check_m_zero() -> i64 {
    let d: i64 = dtw_distance(0, 0, 0, 5, 2);
    if f64_from_bits(d) != 0.0 { return 2; };
    return 0;
}

fn check_n_zero() -> i64 {
    let d: i64 = dtw_distance(0, 5, 0, 0, 2);
    if f64_from_bits(d) != 0.0 { return 4; };
    return 0;
}

fn check_dim_zero() -> i64 {
    let d: i64 = dtw_distance(0, 5, 0, 5, 0);
    if f64_from_bits(d) != 0.0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_ptrs();
    fails = fails + check_m_zero();
    fails = fails + check_n_zero();
    fails = fails + check_dim_zero();
    return fails;
}
