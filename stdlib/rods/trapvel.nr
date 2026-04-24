// rods/trapvel — Trapezoidal velocity profile for point-to-point
// motion with bounded velocity and bounded acceleration.
//
// Foundational profile underneath every robot servo drive, CNC
// controller, and pick-and-place sequencer that needs smooth
// bounded motion.
//
// Three phases:
//   1. Accelerate at +a_max from rest to v_max.
//   2. Cruise at v_max (zero-length if move is too short — the
//      "triangular" degenerate case).
//   3. Decelerate at -a_max to rest at the goal.
//
// Workflow:
//
//   import "stdlib/rods/trapvel.nr"
//
//   let t_total: double;
//   let _ = trapvel_total_time(s0_b, s1_b, v_max_b, a_max_b,
//                               f64_ptr(&t_total));
//
//   // Sample position/velocity/accel at time t.
//   let svr: [3]double;
//   let _ = trapvel_sample(s0_b, s1_b, v_max_b, a_max_b, t_b,
//                           f64_ptr(&svr[0]));
//   // svr[0]=s, svr[1]=v, svr[2]=a
//
// **Limitations** (S-curve / 7-segment jerk-limited / asymmetric
// accel-decel land in v0.6 if needed):
// - Symmetric accel = decel (both = a_max).
// - Discontinuous acceleration at phase transitions (jerk = inf).
// - 1-D scalar moves; multi-axis sync done by caller.
//
// See `stdlib/runtime/trapvel_rt.c`.
#cfile "../runtime/trapvel_rt.c"

extern fn nuc_trapvel_total_time(s0_b: i64, s1_b: i64,
    v_max_b: i64, a_max_b: i64, out_ptr: i64) -> i64;
extern fn nuc_trapvel_sample(s0_b: i64, s1_b: i64,
    v_max_b: i64, a_max_b: i64, t_b: i64, out_ptr: i64) -> i64;

// Compute the total move duration. Writes one f64 to `out_ptr`.
// Returns 1 on success, 0 on bad input (v_max <= 0 or a_max <= 0).
fn trapvel_total_time(s0_b: i64, s1_b: i64,
    v_max_b: i64, a_max_b: i64, out_ptr: i64) -> i64
{
    return nuc_trapvel_total_time(s0_b, s1_b, v_max_b, a_max_b, out_ptr);
}

// Sample (position, velocity, acceleration) at time `t`. Writes
// 3 f64 values (s, v, a) to `out_ptr`. `t` is clamped to
// `[0, total_time]`. Returns 1 on success, 0 on bad input.
fn trapvel_sample(s0_b: i64, s1_b: i64,
    v_max_b: i64, a_max_b: i64, t_b: i64, out_ptr: i64) -> i64
{
    return nuc_trapvel_sample(s0_b, s1_b, v_max_b, a_max_b, t_b, out_ptr);
}
