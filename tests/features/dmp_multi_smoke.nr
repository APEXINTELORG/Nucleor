// helper1 ROBO-2 -- multi-DOF DMP batch wrapper smoke.
//
// Locks train/reset/step/free on a 2-DOF sample-major demonstration:
// the new wrapper owns one scalar DMP per joint and writes a full joint
// vector per step into a caller-owned f64 buffer.

import "stdlib/rods/trajectory.nr"
import "stdlib/rods/f64_buffer.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn main() -> i64 {
    if dmp_multi_new_f64(0, 8, 8.0, 4.0) != 0 { return 1; };
    let one_basis: i64 = dmp_multi_new_f64(1, 1, 8.0, 4.0);
    if one_basis == 0 { return 2; };
    dmp_multi_free_f64(one_basis);

    let dof: i64 = 2;
    let samples: i64 = 5;
    let demo: i64 = f64_buf_new(dof * samples);
    let y0: i64 = f64_buf_new(dof);
    let goal: i64 = f64_buf_new(dof);
    let out: i64 = f64_buf_new(dof);
    if demo == 0 || y0 == 0 || goal == 0 || out == 0 { return 3; };

    // sample-major pairs: (0,1), (0.25,1.5), ..., (1,3)
    f64_buf_set(demo, 0, 0.0);  f64_buf_set(demo, 1, 1.0);
    f64_buf_set(demo, 2, 0.25); f64_buf_set(demo, 3, 1.5);
    f64_buf_set(demo, 4, 0.5);  f64_buf_set(demo, 5, 2.0);
    f64_buf_set(demo, 6, 0.75); f64_buf_set(demo, 7, 2.5);
    f64_buf_set(demo, 8, 1.0);  f64_buf_set(demo, 9, 3.0);

    f64_buf_set(y0, 0, 0.0);
    f64_buf_set(y0, 1, 1.0);
    f64_buf_set(goal, 0, 1.0);
    f64_buf_set(goal, 1, 3.0);

    let h: i64 = dmp_multi_new_f64(dof, 8, 8.0, 4.0);
    if h == 0 {
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 4;
    };

    if dmp_multi_learn_f64(h, f64_buf_ptr(demo), samples, 1.0) != 0 {
        dmp_multi_free_f64(h);
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 8;
    };
    if dmp_multi_reset_f64(h, f64_buf_ptr(y0), f64_buf_ptr(goal), 1.0) != 0 {
        dmp_multi_free_f64(h);
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 16;
    };
    if dmp_multi_step_f64(h, 0.02, f64_buf_ptr(out)) != 0 {
        dmp_multi_free_f64(h);
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 32;
    };
    let first0: f64 = f64_buf_get(out, 0);
    let first1: f64 = f64_buf_get(out, 1);
    if !(first0 > 0.0 && first1 > 1.0) {
        dmp_multi_free_f64(h);
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 64;
    };

    let mut i: i64 = 0;
    while i < 40 {
        dmp_multi_step_f64(h, 0.02, f64_buf_ptr(out));
        i = i + 1;
    };
    let final0: f64 = f64_buf_get(out, 0);
    let final1: f64 = f64_buf_get(out, 1);
    if !(final0 > first0 && final0 < 1.5) {
        dmp_multi_free_f64(h);
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 128;
    };
    if !(final1 > first1 && final1 < 3.8) {
        dmp_multi_free_f64(h);
        f64_buf_free(demo); f64_buf_free(y0); f64_buf_free(goal); f64_buf_free(out);
        return 256;
    };

    dmp_multi_free_f64(h);
    f64_buf_free(demo);
    f64_buf_free(y0);
    f64_buf_free(goal);
    f64_buf_free(out);
    return 0;
}
