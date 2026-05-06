// ROBO-3 Phase 1 -- analytical planar 2-link IK smoke.
//
// Locks a closed-form, non-iterative IK path for a two-revolute-link
// planar arm. Target (1, 1), l1 = l2 = 1 has the elbow-positive
// solution q1 ~= 0, q2 ~= pi/2.

import "stdlib/rods/f64_buffer.nr"
import "stdlib/rods/ik_dls.nr"

fn abs_f64(x: f64) -> f64 {
    if x < 0.0 { return 0.0 - x; };
    return x;
}

fn close(a: f64, b: f64, eps: f64) -> i64 {
    if abs_f64(a - b) < eps { return 1; };
    return 0;
}

fn main() -> i64 {
    let q: i64 = f64_buf_new(2);
    if q == 0 { return 1; };

    let ok: i64 = ik_analytic_planar_2link(1.0, 1.0, 1.0, 1.0, 1, f64_buf_ptr(q));
    if ok != 1 { f64_buf_free(q); return 2; };

    let q1: f64 = f64_buf_get(q, 0);
    let q2: f64 = f64_buf_get(q, 1);
    if close(q1, 0.0, 0.00001) != 1 { f64_buf_free(q); return 4; };
    if close(q2, 1.57079632679, 0.00001) != 1 { f64_buf_free(q); return 8; };

    let no: i64 = ik_analytic_planar_2link(3.0, 0.0, 1.0, 1.0, 1, f64_buf_ptr(q));
    if no != 0 { f64_buf_free(q); return 16; };

    f64_buf_free(q);
    return 0;
}
