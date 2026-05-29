// v0.8.223 stdlib/rods/pursuit.nr first test coverage.
//
// Pure pursuit + Stanley path-following controllers for diff-drive,
// Ackermann, and front-axle steering robots. Pre-v0.8.223: zero
// coverage on the standalone rod.
//
// Setup: a 3-point straight-line path along x-axis: (0,0),
// (5,0), (10,0).
//
// Locks four invariants:
//
//   1. Empty path — pursuit_new(8) → point_count == 0.
//   2. add_point tracks count — 3 add_points → count = 3.
//   3. Distance-to-goal at goal == 0 — at (10, 0).
//   4. Distance-to-goal at start == 10 — straight-line to
//      final waypoint.
//
// Step-fn outputs (omega/delta) are not unit-tested here —
// they require careful pose+lookahead math that's better
// suited to dedicated controller fixtures.
//
// Expected: rc=0.

import "stdlib/rods/pursuit.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_empty_path() -> i64 {
    let p: i64 = pursuit_new(8);
    if pursuit_point_count(p) != 0 { pursuit_free(p); return 1; };
    pursuit_free(p);
    return 0;
}

fn check_add_point_tracks_count() -> i64 {
    let p: i64 = pursuit_new(8);
    pursuit_add_point(p, f64_to_bits(0.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(5.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(10.0), f64_to_bits(0.0));
    if pursuit_point_count(p) != 3 { pursuit_free(p); return 2; };
    pursuit_free(p);
    return 0;
}

fn check_distance_at_goal() -> i64 {
    let p: i64 = pursuit_new(8);
    pursuit_add_point(p, f64_to_bits(0.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(5.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(10.0), f64_to_bits(0.0));
    let d: i64 = pursuit_distance_to_goal(p, f64_to_bits(10.0), f64_to_bits(0.0));
    pursuit_free(p);
    if close(d, f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_distance_at_start() -> i64 {
    let p: i64 = pursuit_new(8);
    pursuit_add_point(p, f64_to_bits(0.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(5.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(10.0), f64_to_bits(0.0));
    let d: i64 = pursuit_distance_to_goal(p, f64_to_bits(0.0), f64_to_bits(0.0));
    pursuit_free(p);
    if close(d, f64_to_bits(10.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_path();
    fails = fails + check_add_point_tracks_count();
    fails = fails + check_distance_at_goal();
    fails = fails + check_distance_at_start();
    return fails;
}
