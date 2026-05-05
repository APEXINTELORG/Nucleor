// v0.8.226 stdlib/rods/twin_core.nr first test coverage.
//
// Dual-core differentiable noise model — runs two statevector
// cores in parallel (Core A clean, Core B noisy depolarizing)
// and extracts differential features for ML noise prediction.
// Pre-v0.8.226: zero coverage on the standalone rod (sister to
// multi_core.nr which generalizes to N cores).
//
// Locks four lifecycle invariants:
//
//   1. **tc_nq round-trip** — tc_init(2, p1, p2) → tc_nq == 2.
//   2. **noise rates round-trip** — tc_p1q / tc_p2q return the
//      values passed to tc_init.
//   3. **Both statevectors are valid** — tc_sv_a and tc_sv_b
//      both return non-zero handles.
//   4. **Distinct statevectors** — tc_sv_a != tc_sv_b (parallel
//      cores, not aliased).
//
// Expected: rc=0.

import "stdlib/rods/twin_core.nr"

fn check_tc_nq_round_trip() -> i64 {
    let tc: i64 = tc_init(2, f64_to_bits(0.001), f64_to_bits(0.005));
    if tc_nq(tc) != 2 { return 1; };
    return 0;
}

fn check_noise_rates_round_trip() -> i64 {
    let p1: i64 = f64_to_bits(0.001);
    let p2: i64 = f64_to_bits(0.005);
    let tc: i64 = tc_init(2, p1, p2);
    if tc_p1q(tc) != p1 { return 2; };
    if tc_p2q(tc) != p2 { return 4; };
    return 0;
}

fn check_statevectors_valid() -> i64 {
    let tc: i64 = tc_init(2, f64_to_bits(0.0), f64_to_bits(0.0));
    if tc_sv_a(tc) == 0 { return 8; };
    if tc_sv_b(tc) == 0 { return 16; };
    return 0;
}

fn check_statevectors_distinct() -> i64 {
    let tc: i64 = tc_init(2, f64_to_bits(0.0), f64_to_bits(0.0));
    if tc_sv_a(tc) == tc_sv_b(tc) { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_tc_nq_round_trip();
    fails = fails + check_noise_rates_round_trip();
    fails = fails + check_statevectors_valid();
    fails = fails + check_statevectors_distinct();
    return fails;
}
