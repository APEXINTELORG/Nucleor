// ROBO-14 Phase 1 -- end-to-end robotics chain smoke.
//
// Exercises the formerly blocked raw-double path:
//   IK -> RRT plan -> CHOMP smooth -> TOPP time profile -> FK endpoint.
//
// The fixture uses a deterministic 2-DOF planar arm plus a fixed tool
// link. Collision callbacks are passed as 0 so planning/smoothing run in
// free space. Expected: rc=0.

import "stdlib/rods/f64_buffer.nr"
import "stdlib/rods/fk_chain.nr"
import "stdlib/rods/ik_dls.nr"
import "stdlib/rods/rrt.nr"
import "stdlib/rods/chomp.nr"
import "stdlib/rods/topp.nr"

fn abs_f64(x: f64) -> f64 {
    if x < 0.0 { return 0.0 - x; };
    return x;
}

fn close(a: f64, b: f64, eps: f64) -> i64 {
    if abs_f64(a - b) < eps { return 1; };
    return 0;
}

fn sqrt_approx(x: f64) -> f64 {
    if x <= 0.0 { return 0.0; };
    let mut g: f64 = x;
    if g < 1.0 { g = 1.0; };
    let mut i: i64 = 0;
    while i < 8 {
        g = 0.5 * (g + x / g);
        i = i + 1;
    };
    return g;
}

fn build_planar_arm() -> i64 {
    let ch: i64 = fk_chain_new();
    if ch == 0 { return 0; };

    // Two revolute z joints and one fixed tool-offset link. In this
    // runtime's FK order, each joint variable affects subsequent links,
    // so the fixed tool link makes joint 1 influence endpoint position.
    let j0: i64 = fk_chain_add_joint_f64(ch, fk_revolute(),
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0);
    if j0 != 0 { fk_chain_free(ch); return 0; };

    let j1: i64 = fk_chain_add_joint_f64(ch, fk_revolute(),
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0);
    if j1 != 1 { fk_chain_free(ch); return 0; };

    let j2: i64 = fk_chain_add_joint_f64(ch, fk_fixed(),
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0);
    if j2 != 2 { fk_chain_free(ch); return 0; };
    return ch;
}

fn path_length(path: i64, n_waypoints: i64, n_dim: i64) -> f64 {
    let mut total: f64 = 0.0;
    let mut i: i64 = 1;
    while i < n_waypoints {
        let mut d: i64 = 0;
        let mut sum: f64 = 0.0;
        while d < n_dim {
            let a: f64 = f64_buf_get(path, (i - 1) * n_dim + d);
            let b: f64 = f64_buf_get(path, i * n_dim + d);
            let dx: f64 = b - a;
            sum = sum + dx * dx;
            d = d + 1;
        };
        total = total + sqrt_approx(sum);
        i = i + 1;
    };
    return total;
}

fn copy_rrt_path_to_buffer(rrt_h: i64, goal_buf: i64, path_buf: i64, n_dim: i64) -> i64 {
    let n_rrt: i64 = rrt_path_len(rrt_h);
    if n_rrt <= 0 { return 0; };
    let mut i: i64 = 0;
    while i < n_rrt {
        let mut d: i64 = 0;
        while d < n_dim {
            let q: f64 = rrt_path_at_f64(rrt_h, i, d);
            if f64_buf_set(path_buf, i * n_dim + d, q) != 1 { return 0; };
            d = d + 1;
        };
        i = i + 1;
    };

    // Clamp the final endpoint to the IK solution. RRT proves the plan
    // path exists; CHOMP endpoints are then exact start/goal constraints.
    let base: i64 = n_rrt * n_dim;
    let mut d2: i64 = 0;
    while d2 < n_dim {
        if f64_buf_set(path_buf, base + d2, f64_buf_get(goal_buf, d2)) != 1 { return 0; };
        d2 = d2 + 1;
    };
    return 1;
}

fn main() -> i64 {
    let n_dim: i64 = 3;
    let ch: i64 = build_planar_arm();
    if ch == 0 { return 1; };

    let start: i64 = f64_buf_new(n_dim);
    let goal: i64 = f64_buf_new(n_dim);
    if start == 0 || goal == 0 { fk_chain_free(ch); return 2; };
    f64_buf_set(start, 0, 0.0); f64_buf_set(start, 1, 0.0); f64_buf_set(start, 2, 0.0);
    f64_buf_set(goal, 0, 0.0); f64_buf_set(goal, 1, 0.0); f64_buf_set(goal, 2, 0.0);

    // IK target: with q0 ~= 0 and q1 ~= pi/2 the tool reaches (2, 1, 0).
    let iters: i64 = ik_dls_solve(ch, f64_buf_ptr(goal),
        f64_to_bits(2.0), f64_to_bits(1.0), f64_to_bits(0.0),
        80, f64_to_bits(0.0001), f64_to_bits(0.05));
    if iters <= 0 { f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 4; };

    if fk_chain_update(ch, f64_buf_ptr(goal)) != 0 { f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 8; };
    if close(fk_chain_link_pos_x_f64(ch, 2), 2.0, 0.05) != 1 {
        f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 16;
    };
    if close(fk_chain_link_pos_y_f64(ch, 2), 1.0, 0.05) != 1 {
        f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 32;
    };

    let r: i64 = rrt_new(n_dim, 12345);
    if r == 0 { f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 64; };
    rrt_set_bounds_f64(r, 0, 0.0 - 3.2, 3.2);
    rrt_set_bounds_f64(r, 1, 0.0 - 3.2, 3.2);
    rrt_set_bounds_f64(r, 2, 0.0, 0.0);
    if rrt_set_root(r, f64_buf_ptr(start)) != 0 {
        rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 128;
    };
    let planned: i64 = rrt_plan_f64(r, f64_buf_ptr(goal), 2000, 0.35, 0);
    if planned != 1 {
        rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 256;
    };
    let n_rrt: i64 = rrt_path_len(r);
    if n_rrt < 2 { rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 512; };

    let n_path: i64 = n_rrt + 1;
    let path: i64 = f64_buf_new(n_path * n_dim);
    if path == 0 { rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 1024; };
    if copy_rrt_path_to_buffer(r, goal, path, n_dim) != 1 {
        f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 2048;
    };

    let cost0: f64 = f64_from_bits(chomp_cost(f64_buf_ptr(path), n_path, n_dim,
        f64_to_bits(1.0), f64_to_bits(0.0), 0));
    let sm_iters: i64 = chomp_optimize(f64_buf_ptr(path), n_path, n_dim,
        25, f64_to_bits(0.05), f64_to_bits(1.0), f64_to_bits(0.0), 0);
    if sm_iters <= 0 { f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 4096; };
    let cost1: f64 = f64_from_bits(chomp_cost(f64_buf_ptr(path), n_path, n_dim,
        f64_to_bits(1.0), f64_to_bits(0.0), 0));
    if cost1 > cost0 + 0.000001 {
        f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 8192;
    };

    let L: f64 = path_length(path, n_path, n_dim);
    if !(L > 0.0) { f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 16384; };
    let tp: i64 = topp_trap_new(f64_to_bits(L), f64_to_bits(1.0), f64_to_bits(2.0));
    if tp == 0 { f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 32768; };
    let T: f64 = f64_from_bits(topp_trap_total_time(tp));
    if !(T > 0.0) { topp_trap_free(tp); f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 65536; };
    if close(f64_from_bits(topp_trap_position(tp, f64_to_bits(T))), L, 0.0001) != 1 {
        topp_trap_free(tp); f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 131072;
    };

    let final_vars: i64 = f64_buf_new(n_dim);
    if final_vars == 0 { topp_trap_free(tp); f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 262144; };
    let mut d3: i64 = 0;
    while d3 < n_dim {
        f64_buf_set(final_vars, d3, f64_buf_get(path, (n_path - 1) * n_dim + d3));
        d3 = d3 + 1;
    };
    if fk_chain_update(ch, f64_buf_ptr(final_vars)) != 0 {
        f64_buf_free(final_vars); topp_trap_free(tp); f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 524288;
    };
    if close(fk_chain_link_pos_x_f64(ch, 2), 2.0, 0.05) != 1 {
        f64_buf_free(final_vars); topp_trap_free(tp); f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 1048576;
    };
    if close(fk_chain_link_pos_y_f64(ch, 2), 1.0, 0.05) != 1 {
        f64_buf_free(final_vars); topp_trap_free(tp); f64_buf_free(path); rrt_free(r); f64_buf_free(start); f64_buf_free(goal); fk_chain_free(ch); return 2097152;
    };

    f64_buf_free(final_vars);
    topp_trap_free(tp);
    f64_buf_free(path);
    rrt_free(r);
    f64_buf_free(start);
    f64_buf_free(goal);
    fk_chain_free(ch);
    return 0;
}
