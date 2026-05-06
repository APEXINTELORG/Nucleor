// ROBO-9 Phase 1 -- Cartesian CHOMP for a planar 2-link arm.
//
// Starts with a straight joint-space path at q=(0, 0), whose FK is
// x=2,y=0 for unit links. The interior Cartesian target path is
// x=1,y=1. The new surface must use analytical FK/Jacobian gradients
// to reduce task-space cost while keeping endpoints clamped.

import "stdlib/rods/f64_buffer.nr"
import "stdlib/rods/chomp.nr"

fn abs_f64(x: f64) -> f64 {
    if x < 0.0 { return 0.0 - x; };
    return x;
}

fn close(a: f64, b: f64, eps: f64) -> i64 {
    if abs_f64(a - b) < eps { return 1; };
    return 0;
}

fn set_pair(buf: i64, i: i64, a: f64, b: f64) -> i64 {
    if f64_buf_set(buf, i * 2, a) != 1 { return 0; };
    if f64_buf_set(buf, i * 2 + 1, b) != 1 { return 0; };
    return 1;
}

fn main() -> i64 {
    let n_path: i64 = 5;
    let path: i64 = f64_buf_new(n_path * 2);
    let target: i64 = f64_buf_new(n_path * 2);
    if path == 0 { return 1; };
    if target == 0 { f64_buf_free(path); return 2; };

    let mut i: i64 = 0;
    while i < n_path {
        if set_pair(path, i, 0.0, 0.0) != 1 {
            f64_buf_free(target); f64_buf_free(path); return 4;
        };
        if i == 0 {
            if set_pair(target, i, 2.0, 0.0) != 1 {
                f64_buf_free(target); f64_buf_free(path); return 8;
            };
        } else {
            if i == n_path - 1 {
                if set_pair(target, i, 2.0, 0.0) != 1 {
                    f64_buf_free(target); f64_buf_free(path); return 16;
                };
            } else {
                if set_pair(target, i, 1.0, 1.0) != 1 {
                    f64_buf_free(target); f64_buf_free(path); return 32;
                };
            };
        };
        i = i + 1;
    };

    let cost0: f64 = f64_from_bits(chomp_cartesian_planar_2link_cost(
        f64_buf_ptr(path), n_path, f64_buf_ptr(target),
        f64_to_bits(0.05), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(1.0)));
    if !(cost0 > 5.0) { f64_buf_free(target); f64_buf_free(path); return 64; };

    let iters: i64 = chomp_optimize_cartesian_planar_2link(
        f64_buf_ptr(path), n_path, f64_buf_ptr(target), 40,
        f64_to_bits(0.20),
        f64_to_bits(0.05),
        f64_to_bits(1.0),
        f64_to_bits(1.0),
        f64_to_bits(1.0),
        f64_to_bits(0.01),
        f64_to_bits(0.20));
    if iters <= 0 { f64_buf_free(target); f64_buf_free(path); return 128; };

    let cost1: f64 = f64_from_bits(chomp_cartesian_planar_2link_cost(
        f64_buf_ptr(path), n_path, f64_buf_ptr(target),
        f64_to_bits(0.05), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(1.0)));
    if !(cost1 < cost0 * 0.70) { f64_buf_free(target); f64_buf_free(path); return 256; };

    if !(f64_buf_get(path, 2) > 0.05) { f64_buf_free(target); f64_buf_free(path); return 512; };
    if !(f64_buf_get(path, 3) > 0.02) { f64_buf_free(target); f64_buf_free(path); return 1024; };
    if close(f64_buf_get(path, 0), 0.0, 0.000001) != 1 {
        f64_buf_free(target); f64_buf_free(path); return 2048;
    };
    if close(f64_buf_get(path, (n_path - 1) * 2), 0.0, 0.000001) != 1 {
        f64_buf_free(target); f64_buf_free(path); return 4096;
    };

    f64_buf_free(target);
    f64_buf_free(path);
    return 0;
}
