// ROBO-10 Phase 1 -- non-empty strict-priority HWBC smoke.
//
// Task 0 (highest priority) commands qdot0 = 1. Task 1 then
// conflicts by asking qdot0 = 0. Task 2 asks for qdot1 = 2, which is
// feasible inside the remaining null space. Expected: the solver keeps
// qdot0 near 1, leaves the conflicting lower task with residual, and
// still satisfies qdot1.

import "stdlib/rods/f64_buffer.nr"
import "stdlib/rods/hwbc.nr"

fn abs_f64(x: f64) -> f64 {
    if x < 0.0 { return 0.0 - x; };
    return x;
}

fn close(a: f64, b: f64, eps: f64) -> i64 {
    if abs_f64(a - b) < eps { return 1; };
    return 0;
}

fn make_row2(a: f64, b: f64) -> i64 {
    let h: i64 = f64_buf_new(2);
    if h == 0 { return 0; };
    f64_buf_set(h, 0, a);
    f64_buf_set(h, 1, b);
    return h;
}

fn make_scalar(x: f64) -> i64 {
    let h: i64 = f64_buf_new(1);
    if h == 0 { return 0; };
    f64_buf_set(h, 0, x);
    return h;
}

fn cleanup(h: i64, j0: i64, x0: i64, j1: i64, x1: i64, j2: i64, x2: i64) {
    if h != 0 { hwbc_free(h); };
    if j0 != 0 { f64_buf_free(j0); };
    if x0 != 0 { f64_buf_free(x0); };
    if j1 != 0 { f64_buf_free(j1); };
    if x1 != 0 { f64_buf_free(x1); };
    if j2 != 0 { f64_buf_free(j2); };
    if x2 != 0 { f64_buf_free(x2); };
}

fn main() -> i64 {
    let h: i64 = hwbc_new(2, f64_to_bits(0.000000001));
    let j0: i64 = make_row2(1.0, 0.0);
    let x0: i64 = make_scalar(1.0);
    let j1: i64 = make_row2(1.0, 0.0);
    let x1: i64 = make_scalar(0.0);
    let j2: i64 = make_row2(0.0, 1.0);
    let x2: i64 = make_scalar(2.0);
    if h == 0 || j0 == 0 || x0 == 0 || j1 == 0 || x1 == 0 || j2 == 0 || x2 == 0 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 1;
    };

    let id0: i64 = hwbc_add_task(h, f64_buf_ptr(j0), f64_buf_ptr(x0), 1);
    let id1: i64 = hwbc_add_task(h, f64_buf_ptr(j1), f64_buf_ptr(x1), 1);
    let id2: i64 = hwbc_add_task(h, f64_buf_ptr(j2), f64_buf_ptr(x2), 1);
    if id0 != 0 || id1 != 1 || id2 != 2 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 2;
    };

    if hwbc_solve(h) != 1 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 4;
    };

    let q0: f64 = f64_from_bits(hwbc_get_qdot(h, 0));
    let q1: f64 = f64_from_bits(hwbc_get_qdot(h, 1));
    let r0: f64 = f64_from_bits(hwbc_task_residual(h, id0));
    let r1: f64 = f64_from_bits(hwbc_task_residual(h, id1));
    let r2: f64 = f64_from_bits(hwbc_task_residual(h, id2));

    if close(q0, 1.0, 0.00001) != 1 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 8;
    };
    if close(q1, 2.0, 0.00001) != 1 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 16;
    };
    if r0 > 0.00001 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 32;
    };
    if r1 < 0.9 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 64;
    };
    if r2 > 0.00001 {
        cleanup(h, j0, x0, j1, x1, j2, x2);
        return 128;
    };

    cleanup(h, j0, x0, j1, x1, j2, x2);
    return 0;
}
