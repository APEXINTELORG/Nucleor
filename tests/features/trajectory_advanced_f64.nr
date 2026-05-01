// stdlib/rods/trajectory — advanced primitives `*_f64` wrappers
// smoke test (DMP / TOPP / Catmull-Rom / Bezier).
//
// v0.4.269: closes the trajectory rod's bits-ABI surface that
// was deferred from v0.4.264's motion-profile wrappers.
//
// Build-only smoke: full DMP training needs a caller-allocated
// double[] demonstration trajectory; full TOPP needs per-joint
// waypoint buffers; Catmull-Rom + Bezier need point buffers.
// This fixture exercises the f64-typed CONSTRUCTORS / SETTERS
// (the no-pointer-arg subset) to confirm the wrappers compile
// + link + their f64 → bits round-trip is well-formed.
//
// EXPECT: build success, runtime exit 0, output "OK trajectory_advanced_f64".

import "stdlib/rods/trajectory.nr"

fn main() -> i32 {
    // === DMP: 5-basis, alpha_z=8, alpha_s=4 ===
    let dmp: i64 = dmp_new_f64(5, 8.0, 4.0);
    if dmp == 0 { print("FAIL dmp_new_f64"); return 1; };

    // dmp_reset with y0=0, goal=1, tau=1 — sets up unroll boundary.
    // We don't have a learned trajectory loaded, but reset still
    // configures the spring-system state machine.
    let r: i64 = dmp_reset_f64(dmp, 0.0, 1.0, 1.0);
    if r != 0 { print("FAIL dmp_reset_f64"); return 1; };

    // dmp_step with dt = 0.01s — without prior dmp_learn, this
    // returns the spring's natural response toward the goal.
    let _y: f64 = dmp_step_f64(dmp, 0.01);

    dmp_free(dmp);

    // === TOPP: 2-DOF solver, configure bounds ===
    let topp: i64 = topp_new(2);
    if topp == 0 { print("FAIL topp_new"); return 1; };

    // Set per-joint vmax/amax via the f64 wrappers.
    topp_set_vmax_f64(topp, 0, 2.0);
    topp_set_vmax_f64(topp, 1, 1.5);
    topp_set_amax_f64(topp, 0, 4.0);
    topp_set_amax_f64(topp, 1, 3.0);

    // Pre-solve, total_time should be -1.0 (per the docstring).
    let t_pre: f64 = topp_total_time_f64(topp);
    // Just check it's negative (< 0) — the runtime returns -1.0
    // bit-cast as the "not solved yet" sentinel.
    if !(t_pre < 0.0) { print("FAIL topp_total_time pre-solve"); return 1; };

    topp_free(topp);

    print("OK trajectory_advanced_f64");
    0
}
