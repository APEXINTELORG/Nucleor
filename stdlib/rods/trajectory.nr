// rods/trajectory — Smooth time-parameterized joint trajectories.
//
// Quintic (5th order) polynomial: given start (q, v, a) and goal
// (q, v, a) over duration T, produce a polynomial that hits both
// boundary conditions exactly with C² continuity (smooth velocity
// and acceleration). Good for actuator-limited systems.
//
//   q(t)  = a0 + a1·t + a2·t² + a3·t³ + a4·t⁴ + a5·t⁵
//   q'(t) =      a1 + 2·a2·t + 3·a3·t² + 4·a4·t³ + 5·a5·t⁴
//   q''(t)=             2·a2 + 6·a3·t + 12·a4·t² + 20·a5·t³
//
// Trapezoidal velocity profiles, S-curves, DMPs, and TOPP-RA
// (time-optimal path parameterization) ship in v0.5 alongside the
// URDF integration.
//
// See `stdlib/runtime/trajectory_rt.c`.
#cfile "../runtime/trajectory_rt.c"

extern fn nuc_quintic_new(
    T_bits: i64,
    q0_bits: i64, v0_bits: i64, a0_bits: i64,
    qT_bits: i64, vT_bits: i64, aT_bits: i64) -> i64;
extern fn nuc_quintic_duration(h: i64) -> i64;
extern fn nuc_quintic_pos_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_quintic_vel_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_quintic_acc_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_quintic_free(h: i64);

fn quintic_new(T_bits: i64,
    q0_bits: i64, v0_bits: i64, a0_bits: i64,
    qT_bits: i64, vT_bits: i64, aT_bits: i64) -> i64 {
    return nuc_quintic_new(T_bits, q0_bits, v0_bits, a0_bits, qT_bits, vT_bits, aT_bits);
}
fn quintic_duration(h: i64) -> i64 { return nuc_quintic_duration(h); }
fn quintic_pos_at(h: i64, t_bits: i64) -> i64 { return nuc_quintic_pos_at(h, t_bits); }
fn quintic_vel_at(h: i64, t_bits: i64) -> i64 { return nuc_quintic_vel_at(h, t_bits); }
fn quintic_acc_at(h: i64, t_bits: i64) -> i64 { return nuc_quintic_acc_at(h, t_bits); }
fn quintic_free(h: i64) { nuc_quintic_free(h); }

// === Trapezoidal velocity profile (v0.2.181) ===
//
// Three-phase profile with constant-acceleration ramp-up, constant-
// velocity cruise, constant-deceleration ramp-down. Respects explicit
// `v_max` and `a_max` limits. If the displacement is too small to
// reach `v_max`, automatically collapses to a triangular (two-phase)
// profile with a lower reachable peak velocity.
//
// Best for actuator-limited systems where hitting velocity /
// acceleration ceilings would saturate the motor controller.
extern fn nuc_trapezoid_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64) -> i64;
extern fn nuc_trapezoid_duration(h: i64) -> i64;
extern fn nuc_trapezoid_peak_v(h: i64) -> i64;
extern fn nuc_trapezoid_pos_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_trapezoid_vel_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_trapezoid_free(h: i64);

fn trapezoid_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64) -> i64 {
    return nuc_trapezoid_new(q0_bits, qT_bits, vmax_bits, amax_bits);
}
fn trapezoid_duration(h: i64) -> i64 { return nuc_trapezoid_duration(h); }
fn trapezoid_peak_v(h: i64) -> i64 { return nuc_trapezoid_peak_v(h); }
fn trapezoid_pos_at(h: i64, t_bits: i64) -> i64 { return nuc_trapezoid_pos_at(h, t_bits); }
fn trapezoid_vel_at(h: i64, t_bits: i64) -> i64 { return nuc_trapezoid_vel_at(h, t_bits); }
fn trapezoid_free(h: i64) { nuc_trapezoid_free(h); }

// === S-curve (bounded-jerk) profile (v0.2.191) ===
//
// Seven-phase profile that respects velocity, acceleration, AND
// jerk limits. Smoother than trapezoidal — no acceleration step;
// the acceleration itself ramps up and down via a constant-jerk
// phase. Industrial CNC, pick-and-place, any system where
// acceleration discontinuities cause residual vibration or
// position overshoot.
//
// For long enough motions, the profile reaches the requested
// `v_max`, `a_max`, and `j_max` plateaus. For shorter motions,
// the profile auto-collapses (constant-accel phase shrinks to
// zero, then cruise phase shrinks to zero) and the actual peak
// v / peak a are reduced. Read back via `scurve_peak_v` /
// `scurve_peak_a`.
extern fn nuc_scurve_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64, jmax_bits: i64) -> i64;
extern fn nuc_scurve_duration(h: i64) -> i64;
extern fn nuc_scurve_peak_v(h: i64) -> i64;
extern fn nuc_scurve_peak_a(h: i64) -> i64;
extern fn nuc_scurve_pos_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_scurve_free(h: i64);

fn scurve_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64, jmax_bits: i64) -> i64 {
    return nuc_scurve_new(q0_bits, qT_bits, vmax_bits, amax_bits, jmax_bits);
}
fn scurve_duration(h: i64) -> i64 { return nuc_scurve_duration(h); }
fn scurve_peak_v(h: i64) -> i64 { return nuc_scurve_peak_v(h); }
fn scurve_peak_a(h: i64) -> i64 { return nuc_scurve_peak_a(h); }
fn scurve_pos_at(h: i64, t_bits: i64) -> i64 { return nuc_scurve_pos_at(h, t_bits); }
fn scurve_free(h: i64) { nuc_scurve_free(h); }

// === Ergonomic f64 wrappers — motion profiles (v0.4.264) ===
//
// Same pattern as units/kinematics/linalg/csv_table/kdt — hide
// the i64-bits-ABI behind f64-typed surface. Adopter writes
// `quintic_new_f64(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0)` instead
// of the seven `f64_to_bits(...)` wraps. Bits-ABI fns above
// remain — purely additive.
//
// Coverage this ship: quintic + trapezoid + s-curve. Advanced
// primitives (DMP, TOPP, Catmull-Rom, Bezier) keep their bits-
// ABI for now — adopters using them already navigate the
// pointer-laden APIs.

// --- Quintic ---
fn quintic_new_f64(
    T: f64,
    q0: f64, v0: f64, a0: f64,
    qT: f64, vT: f64, aT: f64) -> i64
{
    return nuc_quintic_new(
        f64_to_bits(T),
        f64_to_bits(q0), f64_to_bits(v0), f64_to_bits(a0),
        f64_to_bits(qT), f64_to_bits(vT), f64_to_bits(aT));
}
fn quintic_duration_f64(h: i64) -> f64 {
    return f64_from_bits(nuc_quintic_duration(h));
}
fn quintic_pos_at_f64(h: i64, t: f64) -> f64 {
    return f64_from_bits(nuc_quintic_pos_at(h, f64_to_bits(t)));
}
fn quintic_vel_at_f64(h: i64, t: f64) -> f64 {
    return f64_from_bits(nuc_quintic_vel_at(h, f64_to_bits(t)));
}
fn quintic_acc_at_f64(h: i64, t: f64) -> f64 {
    return f64_from_bits(nuc_quintic_acc_at(h, f64_to_bits(t)));
}

// --- Trapezoidal ---
fn trapezoid_new_f64(q0: f64, qT: f64, vmax: f64, amax: f64) -> i64 {
    return nuc_trapezoid_new(
        f64_to_bits(q0), f64_to_bits(qT),
        f64_to_bits(vmax), f64_to_bits(amax));
}
fn trapezoid_duration_f64(h: i64) -> f64 {
    return f64_from_bits(nuc_trapezoid_duration(h));
}
fn trapezoid_peak_v_f64(h: i64) -> f64 {
    return f64_from_bits(nuc_trapezoid_peak_v(h));
}
fn trapezoid_pos_at_f64(h: i64, t: f64) -> f64 {
    return f64_from_bits(nuc_trapezoid_pos_at(h, f64_to_bits(t)));
}
fn trapezoid_vel_at_f64(h: i64, t: f64) -> f64 {
    return f64_from_bits(nuc_trapezoid_vel_at(h, f64_to_bits(t)));
}

// --- S-curve ---
fn scurve_new_f64(q0: f64, qT: f64, vmax: f64, amax: f64, jmax: f64) -> i64 {
    return nuc_scurve_new(
        f64_to_bits(q0), f64_to_bits(qT),
        f64_to_bits(vmax), f64_to_bits(amax), f64_to_bits(jmax));
}
fn scurve_duration_f64(h: i64) -> f64 {
    return f64_from_bits(nuc_scurve_duration(h));
}
fn scurve_peak_v_f64(h: i64) -> f64 {
    return f64_from_bits(nuc_scurve_peak_v(h));
}
fn scurve_peak_a_f64(h: i64) -> f64 {
    return f64_from_bits(nuc_scurve_peak_a(h));
}
fn scurve_pos_at_f64(h: i64, t: f64) -> f64 {
    return f64_from_bits(nuc_scurve_pos_at(h, f64_to_bits(t)));
}

// === Dynamic Movement Primitives (DMP) (v0.2.192) ===
//
// Discrete DMP per Ijspeert et al. 2013. A DMP is a damped
// second-order spring system whose attractor is the goal,
// perturbed by a learnable forcing function shaped from a
// demonstration. Once trained, the DMP can be unrolled with a
// NEW goal — the learned shape generalizes (preserving the
// "style" of the demonstration while adapting start/goal).
//
// Foundation for imitation learning and skill transfer.
//
// Workflow:
//   1. dmp_new(n_basis, alpha_z, alpha_s)       — create
//   2. dmp_learn(dmp, traj_ptr, n_samples, tau) — train from demo
//   3. dmp_reset(dmp, y0, g, tau)               — set up unroll
//   4. loop: y = dmp_step(dmp, dt)              — sample
//
// Multi-DOF: instantiate one DMP per joint.
extern fn nuc_dmp_new(n_basis: i64, alpha_z_b: i64, alpha_s_b: i64) -> i64;
extern fn nuc_dmp_learn(h: i64, traj_ptr: i64, n_samples: i64, tau_b: i64) -> i64;
extern fn nuc_dmp_reset(h: i64, y0_b: i64, g_b: i64, tau_b: i64) -> i64;
extern fn nuc_dmp_step(h: i64, dt_b: i64) -> i64;
extern fn nuc_dmp_free(h: i64);

fn dmp_new(n_basis: i64, alpha_z_b: i64, alpha_s_b: i64) -> i64 {
    return nuc_dmp_new(n_basis, alpha_z_b, alpha_s_b);
}
fn dmp_learn(h: i64, traj_ptr: i64, n_samples: i64, tau_b: i64) -> i64 {
    return nuc_dmp_learn(h, traj_ptr, n_samples, tau_b);
}
fn dmp_reset(h: i64, y0_b: i64, g_b: i64, tau_b: i64) -> i64 {
    return nuc_dmp_reset(h, y0_b, g_b, tau_b);
}
fn dmp_step(h: i64, dt_b: i64) -> i64 { return nuc_dmp_step(h, dt_b); }
fn dmp_free(h: i64) { nuc_dmp_free(h); }

// === TOPP — time-optimal path parameterization (v0.2.203) ===
//
// Pham 2014 / TOPP-RA, simplified for piecewise-linear paths in
// joint space. Given a sequence of N waypoints and per-joint
// velocity + acceleration bounds, computes the time-optimal
// parameterization via the standard forward + backward pass on
// the squared path velocity b(s) = (ds/dt)².
//
// Workflow:
//   1. topp_new(n_dim)                          — create solver
//   2. topp_set_vmax(h, j, vmax_b) for each j   — joint vel bounds
//   3. topp_set_amax(h, j, amax_b) for each j   — joint accel bounds
//   4. for each waypoint: topp_add_waypoint(h, q_ptr)
//   5. topp_solve(h)                            — run forward+backward
//   6. read total_time / per-waypoint time / path velocity
//
// **Limitations** (full TOPP-RA via convex optimization on a per-
// step basis lands in v0.6 if needed):
// - Only piecewise-linear paths. Sample splines first.
// - Symmetric box bounds only.
// - Pure kinematic (no torque/dynamics constraints).
extern fn nuc_topp_new(n_dim: i64) -> i64;
extern fn nuc_topp_add_waypoint(h: i64, q_ptr: i64) -> i64;
extern fn nuc_topp_set_vmax(h: i64, j: i64, vmax_b: i64);
extern fn nuc_topp_set_amax(h: i64, j: i64, amax_b: i64);
extern fn nuc_topp_solve(h: i64) -> i64;
extern fn nuc_topp_total_time(h: i64) -> i64;
extern fn nuc_topp_time_at_waypoint(h: i64, i: i64) -> i64;
extern fn nuc_topp_path_velocity(h: i64, i: i64) -> i64;
extern fn nuc_topp_waypoint_count(h: i64) -> i64;
extern fn nuc_topp_free(h: i64);

fn topp_new(n_dim: i64) -> i64 { return nuc_topp_new(n_dim); }
fn topp_add_waypoint(h: i64, q_ptr: i64) -> i64 {
    return nuc_topp_add_waypoint(h, q_ptr);
}
fn topp_set_vmax(h: i64, j: i64, vmax_b: i64) { nuc_topp_set_vmax(h, j, vmax_b); }
fn topp_set_amax(h: i64, j: i64, amax_b: i64) { nuc_topp_set_amax(h, j, amax_b); }
fn topp_solve(h: i64) -> i64 { return nuc_topp_solve(h); }

// Total traversal time of the parameterized path, as bit-cast f64.
// Returns -1.0 (bit-cast) if not yet solved.
fn topp_total_time(h: i64) -> i64 { return nuc_topp_total_time(h); }

// Cumulative time at waypoint `i`, as bit-cast f64.
fn topp_time_at_waypoint(h: i64, i: i64) -> i64 {
    return nuc_topp_time_at_waypoint(h, i);
}

// Path velocity (s_dot) at waypoint `i`, as bit-cast f64. Useful
// for verifying boundary conditions (s_dot[0] and s_dot[N-1] should
// both be 0 by default).
fn topp_path_velocity(h: i64, i: i64) -> i64 {
    return nuc_topp_path_velocity(h, i);
}

fn topp_waypoint_count(h: i64) -> i64 { return nuc_topp_waypoint_count(h); }
fn topp_free(h: i64) { nuc_topp_free(h); }

// === Catmull-Rom spline (v0.2.237) ===
//
// C¹ interpolating spline through arbitrary waypoints. Standard
// smoothing primitive: pass through every waypoint exactly, with
// continuous tangent across waypoint boundaries. Common workflow:
// run RRT/PRM to get a discrete path → smooth with Catmull-Rom →
// time-parameterize with TOPP.
//
// Workflow:
//   let cr = catmull_new(n_dim);
//   for each waypoint: catmull_add_waypoint(cr, q_ptr);
//   // Sample at parameter s ∈ [0, n_pts - 1]:
//   catmull_eval(cr, s_b, q_out_ptr);
extern fn nuc_catmull_new(n_dim: i64) -> i64;
extern fn nuc_catmull_add_waypoint(h: i64, q_ptr: i64) -> i64;
extern fn nuc_catmull_waypoint_count(h: i64) -> i64;
extern fn nuc_catmull_eval(h: i64, s_b: i64, q_out_ptr: i64) -> i64;
extern fn nuc_catmull_free(h: i64);

fn catmull_new(n_dim: i64) -> i64 { return nuc_catmull_new(n_dim); }
fn catmull_add_waypoint(h: i64, q_ptr: i64) -> i64 {
    return nuc_catmull_add_waypoint(h, q_ptr);
}
fn catmull_waypoint_count(h: i64) -> i64 { return nuc_catmull_waypoint_count(h); }

// Evaluate spline at parameter s (0 to n_pts - 1). Writes n_dim
// doubles to q_out_ptr. Returns 0 on success, -1 on bad input.
fn catmull_eval(h: i64, s_b: i64, q_out_ptr: i64) -> i64 {
    return nuc_catmull_eval(h, s_b, q_out_ptr);
}

fn catmull_free(h: i64) { nuc_catmull_free(h); }

// === Cubic Bezier (v0.2.242) ===
//
// Standard 4-control-point Bezier. Pairs with Catmull-Rom:
// Catmull-Rom passes through every waypoint exactly (good for
// path-following); Bezier offers explicit tangent control at
// endpoints via the inner control points (good for smooth merges
// with existing trajectories).
//
//   B(t) = (1-t)³·P₀ + 3(1-t)²t·P₁ + 3(1-t)t²·P₂ + t³·P₃
//
// `pts_ptr` is a flat `double[4 * n_dim]` array of P₀..P₃.
extern fn nuc_bezier_eval(pts_ptr: i64, n_dim: i64,
    t_b: i64, q_out_ptr: i64) -> i64;
extern fn nuc_bezier_tangent(pts_ptr: i64, n_dim: i64,
    t_b: i64, dq_out_ptr: i64) -> i64;

// Evaluate cubic Bezier at parameter t ∈ [0, 1].
fn bezier_eval(pts_ptr: i64, n_dim: i64,
    t_b: i64, q_out_ptr: i64) -> i64
{
    return nuc_bezier_eval(pts_ptr, n_dim, t_b, q_out_ptr);
}

// First derivative B'(t) = 3·[(1-t)²·(P₁-P₀) + 2(1-t)t·(P₂-P₁) + t²·(P₃-P₂)].
// Useful for computing instantaneous tangent / velocity along the curve.
fn bezier_tangent(pts_ptr: i64, n_dim: i64,
    t_b: i64, dq_out_ptr: i64) -> i64
{
    return nuc_bezier_tangent(pts_ptr, n_dim, t_b, dq_out_ptr);
}
