// rods/bicycle — Kinematic bicycle model forward integration.
//
// Treats a car as two wheels on a single axle (front steerable,
// rear driven). Standard kinematics:
//
//   `ẋ = v cos(θ)`
//   `ẏ = v sin(θ)`
//   `θ̇ = (v / L) tan(δ)`
//
//   `(x, y, θ)` = REAR axle pose (world frame)
//   `v` = forward speed at rear axle (m/s)
//   `δ` = front-wheel steering angle (rad)
//   `L` = wheelbase (m)
//
// Two integrators:
//   `bicycle_step_euler` — single forward Euler step (fast).
//   `bicycle_step_rk4`   — single RK4 step (4× cost, much
//                          better at large `dt` / tight curvature).
//
// Pair with `purepursuit.nr` / `stanley.nr` to close the loop:
// controller → `δ`, integrator → next pose, repeat.
//
// Workflow:
//
//   import "stdlib/rods/bicycle.nr"
//
//   // out: double[3] — { x, y, theta }
//   let ok = bicycle_step_rk4(x_b, y_b, theta_b,
//                              v_b, delta_b,
//                              wheelbase_b, dt_b,
//                              out_ptr);
//
// **Limitations** (full dynamic bicycle with tire slip / Pacejka
// model land in v0.6 if needed):
// - Kinematic only — assumes no wheel slip (low-speed regime).
// - Caller must clamp `δ` to vehicle limits.
//
// See `stdlib/runtime/bicycle_rt.c`.
#cfile "../runtime/bicycle_rt.c"

extern fn nuc_bicycle_step_euler(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, delta_b: i64,
    L_b: i64, dt_b: i64, out_ptr: i64) -> i64;
extern fn nuc_bicycle_step_rk4(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, delta_b: i64,
    L_b: i64, dt_b: i64, out_ptr: i64) -> i64;

// Forward Euler step.
fn bicycle_step_euler(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, delta_b: i64,
    L_b: i64, dt_b: i64, out_ptr: i64) -> i64
{
    return nuc_bicycle_step_euler(x_b, y_b, theta_b, v_b, delta_b,
        L_b, dt_b, out_ptr);
}

// Classical RK4 step.
fn bicycle_step_rk4(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, delta_b: i64,
    L_b: i64, dt_b: i64, out_ptr: i64) -> i64
{
    return nuc_bicycle_step_rk4(x_b, y_b, theta_b, v_b, delta_b,
        L_b, dt_b, out_ptr);
}
