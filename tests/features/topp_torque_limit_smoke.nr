// ROBO-1 Phase 1 -- TOPP diagonal torque-limit acceleration tightening.
//
// The existing multi-DOF TOPP solver is kinematic by default. This
// fixture sets a diagonal inertia and tau_max for one joint so the
// effective acceleration becomes min(amax, tau_max / inertia). The
// torque-limited solve must take materially longer than the same path
// with only kinematic acceleration limits.

import "stdlib/rods/f64_buffer.nr"
import "stdlib/rods/trajectory.nr"

fn abs_f64(x: f64) -> f64 {
    if x < 0.0 { return 0.0 - x; };
    return x;
}

fn close(a: f64, b: f64, eps: f64) -> i64 {
    if abs_f64(a - b) < eps { return 1; };
    return 0;
}

fn add_unit_path(h: i64, q0: i64, q1: i64) -> i64 {
    if topp_add_waypoint(h, f64_buf_ptr(q0)) != 0 { return 0; };
    if topp_add_waypoint(h, f64_buf_ptr(q1)) != 1 { return 0; };
    return 1;
}

fn main() -> i64 {
    let q0: i64 = f64_buf_new(1);
    let q1: i64 = f64_buf_new(1);
    if q0 == 0 || q1 == 0 { return 1; };
    f64_buf_set(q0, 0, 0.0);
    f64_buf_set(q1, 0, 1.0);

    let base: i64 = topp_new(1);
    let limited: i64 = topp_new(1);
    if base == 0 || limited == 0 {
        if base != 0 { topp_free(base); };
        if limited != 0 { topp_free(limited); };
        f64_buf_free(q0); f64_buf_free(q1);
        return 2;
    };

    topp_set_vmax_f64(base, 0, 100.0);
    topp_set_amax_f64(base, 0, 10.0);
    if add_unit_path(base, q0, q1) != 1 { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 4; };
    if topp_solve(base) != 0 { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 8; };
    let base_t: f64 = topp_total_time_f64(base);

    topp_set_vmax_f64(limited, 0, 100.0);
    topp_set_amax_f64(limited, 0, 10.0);
    topp_set_inertia_f64(limited, 0, 2.0);
    topp_set_tau_max_f64(limited, 0, 1.0);
    if close(topp_effective_amax_f64(limited, 0), 0.5, 0.000001) != 1 {
        topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1);
        return 16;
    };
    if add_unit_path(limited, q0, q1) != 1 { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 32; };
    if topp_solve(limited) != 0 { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 64; };
    let limited_t: f64 = topp_total_time_f64(limited);

    if !(base_t > 0.0) { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 128; };
    if limited_t < 2.7 { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 256; };
    if limited_t < base_t + 2.0 { topp_free(base); topp_free(limited); f64_buf_free(q0); f64_buf_free(q1); return 512; };

    topp_free(base);
    topp_free(limited);
    f64_buf_free(q0);
    f64_buf_free(q1);
    return 0;
}
