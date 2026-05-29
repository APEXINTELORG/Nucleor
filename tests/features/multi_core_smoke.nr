// v0.8.229 stdlib/rods/multi_core.nr first test coverage.
//
// N-core quantum noise ensemble — extends twin_core from 2 to N
// cores. Core 0 is clean (no noise); cores 1..N-1 have spread
// noise rates. Pre-v0.8.229: zero coverage on the standalone
// rod (sister to twin_core_smoke v0.8.226).
//
// Setup: 2 qubits, 4 cores, p1q_base=0.001, p2q_base=0.005.
//
// Locks four lifecycle invariants:
//
//   1. mc_ncores returns n_cores arg — round-trip 4 → 4.
//   2. mc_nq returns nq arg — round-trip 2 → 2.
//   3. Step counter starts at 0 — fresh ensemble, no ops.
//   4. Core 0 is clean (zero noise) — mc_p1q(c=0) == 0
//      bitcast (regardless of p1q_base setting).
//
// Expected: rc=0.

import "stdlib/rods/multi_core.nr"

fn check_ncores() -> i64 {
    let mc: i64 = mc_init(2, 4, f64_to_bits(0.001), f64_to_bits(0.005));
    if mc_ncores(mc) != 4 { return 1; };
    return 0;
}

fn check_nq() -> i64 {
    let mc: i64 = mc_init(2, 4, f64_to_bits(0.001), f64_to_bits(0.005));
    if mc_nq(mc) != 2 { return 2; };
    return 0;
}

fn check_step_zero() -> i64 {
    let mc: i64 = mc_init(2, 4, f64_to_bits(0.001), f64_to_bits(0.005));
    if mc_step_count(mc) != 0 { return 4; };
    return 0;
}

fn check_core0_clean() -> i64 {
    let mc: i64 = mc_init(2, 4, f64_to_bits(0.001), f64_to_bits(0.005));
    let p1: i64 = mc_p1q(mc, 0);
    let p2: i64 = mc_p2q(mc, 0);
    if f64_from_bits(p1) != 0.0 { return 8; };
    if f64_from_bits(p2) != 0.0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_ncores();
    fails = fails + check_nq();
    fails = fails + check_step_zero();
    fails = fails + check_core0_clean();
    return fails;
}
