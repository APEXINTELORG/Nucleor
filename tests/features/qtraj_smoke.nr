// v0.8.201 stdlib/rods/qtraj.nr first test coverage.
//
// Minimum-snap polynomial trajectory generator (Mellinger &
// Kumar 2011). Pre-v0.8.201: zero coverage.
//
// Locks four lifecycle invariants on a 2-segment trajectory
// (3 waypoints):
//   1. Construction with n_seg=2 → handle, n_segments=2.
//   2. total_time == sum of segment times (1+1=2).
//   3. Solve returns success: 1 on valid input.
//   4. Boundary at t=0: `evaluate_total(deriv=0, t=0)` ==
//      first waypoint.
//
// Expected: rc=0.

import "stdlib/rods/qtraj.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let h: i64 = qtraj_new(2);
    if h == 0 { return 1; };
    if qtraj_n_segments(h) != 2 { qtraj_free(h); return 2; };
    qtraj_free(h);
    return 0;
}

fn check_total_time() -> i64 {
    let h: i64 = qtraj_new(2);
    qtraj_set_segment_time(h, 0, f64_to_bits(1.0));
    qtraj_set_segment_time(h, 1, f64_to_bits(1.0));
    if close(qtraj_total_time(h), f64_to_bits(2.0), 1e-9) != 1 { qtraj_free(h); return 4; };
    qtraj_free(h);
    return 0;
}

fn check_solve_success() -> i64 {
    let h: i64 = qtraj_new(2);
    qtraj_set_segment_time(h, 0, f64_to_bits(1.0));
    qtraj_set_segment_time(h, 1, f64_to_bits(1.0));
    qtraj_set_waypoint(h, 0, f64_to_bits(0.0));
    qtraj_set_waypoint(h, 1, f64_to_bits(5.0));
    qtraj_set_waypoint(h, 2, f64_to_bits(10.0));
    if qtraj_solve(h) != 1 { qtraj_free(h); return 8; };
    qtraj_free(h);
    return 0;
}

fn check_boundary_at_t0() -> i64 {
    let h: i64 = qtraj_new(2);
    qtraj_set_segment_time(h, 0, f64_to_bits(1.0));
    qtraj_set_segment_time(h, 1, f64_to_bits(1.0));
    qtraj_set_waypoint(h, 0, f64_to_bits(3.0));
    qtraj_set_waypoint(h, 1, f64_to_bits(5.0));
    qtraj_set_waypoint(h, 2, f64_to_bits(8.0));
    qtraj_solve(h);
    let v0: i64 = qtraj_evaluate_total(h, 0, f64_to_bits(0.0));
    qtraj_free(h);
    if close(v0, f64_to_bits(3.0), 1e-3) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_total_time();
    fails = fails + check_solve_success();
    fails = fails + check_boundary_at_t0();
    return fails;
}
