// ROBO-8 Phase 1 -- CHOMP covariant smoothness preconditioner smoke.
//
// A 1D zig-zag path with clamped endpoints has smoothness gradient
// grad = 2Aq. One covariant step with alpha=0.5 and no obstacle term
// should apply A^-1 grad = 2q and collapse the interior zig-zag while
// leaving endpoints unchanged.

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

fn main() -> i64 {
    let n_path: i64 = 5;
    let n_dim: i64 = 1;
    let path: i64 = f64_buf_new(n_path * n_dim);
    if path == 0 { return 1; };

    f64_buf_set(path, 0, 0.0);
    f64_buf_set(path, 1, 3.0);
    f64_buf_set(path, 2, 0.0 - 3.0);
    f64_buf_set(path, 3, 3.0);
    f64_buf_set(path, 4, 0.0);

    let cost0: f64 = f64_from_bits(chomp_cost(f64_buf_ptr(path), n_path, n_dim,
        f64_to_bits(1.0), f64_to_bits(0.0), 0));
    if !(cost0 > 0.0) { f64_buf_free(path); return 2; };

    let iters: i64 = chomp_optimize_covariant(f64_buf_ptr(path), n_path, n_dim,
        1,
        f64_to_bits(0.5),
        f64_to_bits(1.0),
        f64_to_bits(0.0),
        0,
        f64_to_bits(0.0),
        f64_to_bits(0.0));
    if iters != 1 { f64_buf_free(path); return 4; };

    let cost1: f64 = f64_from_bits(chomp_cost(f64_buf_ptr(path), n_path, n_dim,
        f64_to_bits(1.0), f64_to_bits(0.0), 0));
    if cost1 > cost0 * 0.01 { f64_buf_free(path); return 8; };

    if close(f64_buf_get(path, 0), 0.0, 0.00001) != 1 { f64_buf_free(path); return 16; };
    if close(f64_buf_get(path, 4), 0.0, 0.00001) != 1 { f64_buf_free(path); return 32; };
    if close(f64_buf_get(path, 1), 0.0, 0.00001) != 1 { f64_buf_free(path); return 64; };
    if close(f64_buf_get(path, 2), 0.0, 0.00001) != 1 { f64_buf_free(path); return 128; };
    if close(f64_buf_get(path, 3), 0.0, 0.00001) != 1 { f64_buf_free(path); return 256; };

    f64_buf_free(path);
    return 0;
}
