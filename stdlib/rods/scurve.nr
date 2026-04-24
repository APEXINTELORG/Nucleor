// rods/scurve — Jerk-limited (7-phase) s-curve time-parameterization
// for an arc-length path.
//
// Production-grade motion-control profile. Where `topp.nr`'s
// trapezoidal profile bounds velocity + acceleration, this rod
// additionally bounds jerk — eliminating the δ-spike acceleration
// jumps that cause robot lurching, vibration, and reduced lifetime
// of joints.
//
// Phases (jerk j is constant within each):
//   1. j = +j_max     a:0 → a_max          duration T_j = a_max / j_max
//   2. j = 0          a = a_max constant    duration T_a − 2·T_j
//   3. j = −j_max     a: a_max → 0         duration T_j
//   4. j = 0          cruise at v_max        duration T_v
//   5. j = −j_max     a: 0 → −a_max        duration T_j
//   6. j = 0          a = −a_max constant    duration T_a − 2·T_j
//   7. j = +j_max     a: −a_max → 0        duration T_j
//
// where `T_a = T_j + v_max/a_max`, `T_v = L/v_max − T_a`,
// `T_total = 2·T_a + T_v`.
//
// Workflow:
//
//   import "stdlib/rods/scurve.nr"
//
//   let h = scurve_new(L_b, v_max_b, a_max_b, j_max_b);
//   if h == 0 {
//       // Path too short for full 7-phase profile —
//       // fall back to topp.nr's trapezoidal.
//   }
//   let T = scurve_total_time(h);
//   for tick {
//       let s_b = scurve_position(h, t_b);
//       let v_b = scurve_velocity(h, t_b);
//       let a_b = scurve_acceleration(h, t_b);
//       let j_b = scurve_jerk(h, t_b);
//   }
//   scurve_free(h);
//
// **Limitations** (degenerate cases / asymmetric / online retiming
// land in v0.6 if needed):
// - Requires the FULL 7-phase profile — both v_max and a_max must
//   be reached. `scurve_new` returns 0 for paths too short to
//   satisfy that. Use `topp.nr` for the trapezoidal fallback.
// - Symmetric (accel = decel limits).
// - Rest-to-rest only (no nonzero start/end velocities).
//
// See `stdlib/runtime/scurve_rt.c`.
#cfile "../runtime/scurve_rt.c"

extern fn nuc_scurve_new(L_b: i64, v_max_b: i64, a_max_b: i64, j_max_b: i64) -> i64;
extern fn nuc_scurve_total_time(h: i64) -> i64;
extern fn nuc_scurve_path_length(h: i64) -> i64;
extern fn nuc_scurve_position(h: i64, t_b: i64) -> i64;
extern fn nuc_scurve_velocity(h: i64, t_b: i64) -> i64;
extern fn nuc_scurve_acceleration(h: i64, t_b: i64) -> i64;
extern fn nuc_scurve_jerk(h: i64, t_b: i64) -> i64;
extern fn nuc_scurve_free(h: i64);

// Construct an s-curve trajectory. Returns 0 if the path is too
// short for the full 7-phase profile (use `topp.nr`'s trapezoidal
// fallback) or any input is non-positive.
fn scurve_new(L_b: i64, v_max_b: i64, a_max_b: i64, j_max_b: i64) -> i64 {
    return nuc_scurve_new(L_b, v_max_b, a_max_b, j_max_b);
}

fn scurve_total_time(h: i64)  -> i64 { return nuc_scurve_total_time(h); }
fn scurve_path_length(h: i64) -> i64 { return nuc_scurve_path_length(h); }

// Evaluate position / velocity / acceleration / jerk at time t.
// Outside [0, T_total], position is clipped to [0, L] and
// derivatives are 0.
fn scurve_position(h: i64, t_b: i64)     -> i64 { return nuc_scurve_position(h, t_b); }
fn scurve_velocity(h: i64, t_b: i64)     -> i64 { return nuc_scurve_velocity(h, t_b); }
fn scurve_acceleration(h: i64, t_b: i64) -> i64 { return nuc_scurve_acceleration(h, t_b); }
fn scurve_jerk(h: i64, t_b: i64)         -> i64 { return nuc_scurve_jerk(h, t_b); }

fn scurve_free(h: i64) { nuc_scurve_free(h); }
