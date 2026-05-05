// v0.8.182 stdlib/rods/topp.nr first test coverage.
//
// Trapezoidal time-parameterization for 1-D arc-length paths.
// Pre-v0.8.182: zero coverage.
//
// Locks four textbook trapezoidal-profile invariants on a long-
// enough path (L=10, v_max=2, a_max=1) where the cruise phase
// fits:
//
//   1. **Construction returns valid handle** for positive inputs.
//   2. **path_length round-trip**: L=10 in → 10.0 out.
//   3. **peak_velocity == v_max** when path is long enough for cruise.
//   4. **Position at t=0 is 0**, position at t=T is L (boundary).
//
// Expected: rc=0.

import "stdlib/rods/topp.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_handle() -> i64 {
    let h: i64 = topp_trap_new(f64_to_bits(10.0), f64_to_bits(2.0), f64_to_bits(1.0));
    if h == 0 { return 1; };
    topp_trap_free(h);
    return 0;
}

fn check_path_length() -> i64 {
    let h: i64 = topp_trap_new(f64_to_bits(10.0), f64_to_bits(2.0), f64_to_bits(1.0));
    if close(topp_trap_path_length(h), f64_to_bits(10.0), 1e-9) != 1 { topp_trap_free(h); return 2; };
    topp_trap_free(h);
    return 0;
}

fn check_peak_velocity() -> i64 {
    // L=10 long enough for cruise → peak == v_max
    let h: i64 = topp_trap_new(f64_to_bits(10.0), f64_to_bits(2.0), f64_to_bits(1.0));
    if close(topp_trap_peak_velocity(h), f64_to_bits(2.0), 1e-6) != 1 { topp_trap_free(h); return 4; };
    topp_trap_free(h);
    return 0;
}

fn check_position_endpoints() -> i64 {
    let h: i64 = topp_trap_new(f64_to_bits(10.0), f64_to_bits(2.0), f64_to_bits(1.0));
    let pos_0: i64 = topp_trap_position(h, f64_to_bits(0.0));
    if close(pos_0, f64_to_bits(0.0), 1e-9) != 1 { topp_trap_free(h); return 8; };
    let total_t: i64 = topp_trap_total_time(h);
    let pos_end: i64 = topp_trap_position(h, total_t);
    if close(pos_end, f64_to_bits(10.0), 1e-6) != 1 { topp_trap_free(h); return 16; };
    topp_trap_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_handle();
    fails = fails + check_path_length();
    fails = fails + check_peak_velocity();
    fails = fails + check_position_endpoints();
    return fails;
}
