// helper1 ROBO-4 -- 6D IK nullspace posture smoke.
//
// A prismatic x joint solves the 6D pose target while an additional fixed
// joint is task-invisible. The 6D nullspace solver should move that redundant
// fixed-joint variable toward q_pref without blocking the pose solve.

import "stdlib/rods/ik_dls.nr"
import "stdlib/rods/f64_buffer.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn main() -> i64 {
    let ch: i64 = fk_chain_new();
    if ch == 0 { return 1; };
    if fk_chain_add_joint_f64(ch, fk_prismatic(),
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        1.0, 0.0, 0.0) != 0 {
        fk_chain_free(ch);
        return 2;
    };
    if fk_chain_add_joint_f64(ch, fk_fixed(),
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0) != 1 {
        fk_chain_free(ch);
        return 4;
    };

    let vars: i64 = f64_buf_new(2);
    let pref: i64 = f64_buf_new(2);
    if vars == 0 || pref == 0 { fk_chain_free(ch); return 8; };
    f64_buf_set(vars, 0, 0.0);
    f64_buf_set(vars, 1, 0.0 - 2.0);
    f64_buf_set(pref, 0, 0.0);
    f64_buf_set(pref, 1, 1.5);

    let iters: i64 = ik_dls_solve_6d_nullspace(ch, f64_buf_ptr(vars),
        f64_to_bits(0.5), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_buf_ptr(pref), f64_to_bits(0.25),
        32, f64_to_bits(0.000001), f64_to_bits(0.05), f64_to_bits(1.0));
    if iters <= 0 { f64_buf_free(vars); f64_buf_free(pref); fk_chain_free(ch); return 16; };

    if fk_chain_update(ch, f64_buf_ptr(vars)) != 0 {
        f64_buf_free(vars); f64_buf_free(pref); fk_chain_free(ch); return 32;
    };
    if close(fk_chain_link_pos_x_f64(ch, 1), 0.5, 0.01) != 1 {
        f64_buf_free(vars); f64_buf_free(pref); fk_chain_free(ch); return 64;
    };
    if f64_buf_get(vars, 1) <= (0.0 - 1.0) {
        f64_buf_free(vars); f64_buf_free(pref); fk_chain_free(ch); return 128;
    };

    f64_buf_free(vars);
    f64_buf_free(pref);
    fk_chain_free(ch);
    return 0;
}
