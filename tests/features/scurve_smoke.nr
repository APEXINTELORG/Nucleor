// v0.8.199 stdlib/rods/scurve.nr first test coverage.
//
// Jerk-limited 7-phase s-curve time-parameterization.
// Pre-v0.8.199: zero coverage.
//
// Locks four invariants on a long path that fits the full
// 7-phase profile (L=100, v_max=2, a_max=1, j_max=2):
//
//   1. Construction returns valid handle for full-profile path.
//   2. Path length round-trip: L=100 in → 100 out.
//   3. Boundary at t=0: position == 0.
//   4. Boundary at t=T_total: position ≈ L.
//
// Sister to v0.8.182 topp_smoke (trapezoidal). The s-curve is
// production-grade jerk-limited; topp is the simpler fallback.
//
// Expected: rc=0.

import "stdlib/rods/scurve.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let h: i64 = scurve_new(
        f64_to_bits(100.0), f64_to_bits(2.0),
        f64_to_bits(1.0),   f64_to_bits(2.0)
    );
    if h == 0 { return 1; };
    scurve_free(h);
    return 0;
}

fn check_path_length() -> i64 {
    let h: i64 = scurve_new(
        f64_to_bits(100.0), f64_to_bits(2.0),
        f64_to_bits(1.0),   f64_to_bits(2.0)
    );
    if close(scurve_path_length(h), f64_to_bits(100.0), 1e-9) != 1 { scurve_free(h); return 2; };
    scurve_free(h);
    return 0;
}

fn check_position_at_0() -> i64 {
    let h: i64 = scurve_new(
        f64_to_bits(100.0), f64_to_bits(2.0),
        f64_to_bits(1.0),   f64_to_bits(2.0)
    );
    let p: i64 = scurve_position(h, f64_to_bits(0.0));
    scurve_free(h);
    if close(p, f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_position_at_T() -> i64 {
    let h: i64 = scurve_new(
        f64_to_bits(100.0), f64_to_bits(2.0),
        f64_to_bits(1.0),   f64_to_bits(2.0)
    );
    let total_t: i64 = scurve_total_time(h);
    let p: i64 = scurve_position(h, total_t);
    scurve_free(h);
    if close(p, f64_to_bits(100.0), 1e-3) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_path_length();
    fails = fails + check_position_at_0();
    fails = fails + check_position_at_T();
    return fails;
}
