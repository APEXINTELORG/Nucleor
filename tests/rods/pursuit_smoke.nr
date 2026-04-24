// rods/pursuit — verify rod wrapper compiles + links (v0.2.229 ship).
// Build a simple straight-line path and exercise the controller
// step at a couple of poses. Functional correctness coverage in
// the direct C unit test (drive a robot toward a goal and watch
// distance decrease).
import "stdlib/rods/pursuit.nr"

fn f64_to_bits(x: f64) -> i64 { return x as i64; }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let p: i64 = pursuit_new(8);
    if p == 0 { print("FAIL pursuit_new"); return 1; };

    pursuit_add_point(p, f64_to_bits(0.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(1.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(2.0), f64_to_bits(0.0));
    pursuit_add_point(p, f64_to_bits(3.0), f64_to_bits(0.0));

    if pursuit_point_count(p) != 4 {
        fail = fail + 1; print("FAIL pursuit_point_count");
    };

    // Distance to goal from origin = 3.0 (last waypoint at x=3).
    let _d: i64 = pursuit_distance_to_goal(p, f64_to_bits(0.0), f64_to_bits(0.0));

    // Differential-drive step at origin facing +x with v=1, L=1.
    // Pure pursuit returns omega = 0 since lookahead is straight ahead.
    let _omega: i64 = pursuit_step_diff_drive(p,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0));

    pursuit_free(p);
    if fail == 0 { print("OK pursuit_smoke"); };
    return fail;
}
