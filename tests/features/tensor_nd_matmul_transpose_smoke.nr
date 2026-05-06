// Helper1 v0856: ML-2 / ML-3 tensor_nd 2D matmul + transpose coverage.
//
// Locks:
//   1. tensor_new_2d produces rank-2 shape metadata.
//   2. tensor_matmul computes a 2x3 @ 3x2 product.
//   3. tensor_transpose returns A^T with shape 3x2.
//   4. tensor_matmul returns 0 for incompatible shapes.
//   5. tensor_limitations names the shipped 2D surface.
//
// Expected: rc=0.

import "stdlib/rods/tensor_nd.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_a() -> i64 {
    let a: i64 = tensor_new_2d(2, 3);
    tensor_set_flat(a, 0, f64_to_bits(1.0));
    tensor_set_flat(a, 1, f64_to_bits(2.0));
    tensor_set_flat(a, 2, f64_to_bits(3.0));
    tensor_set_flat(a, 3, f64_to_bits(4.0));
    tensor_set_flat(a, 4, f64_to_bits(5.0));
    tensor_set_flat(a, 5, f64_to_bits(6.0));
    return a;
}

fn make_b() -> i64 {
    let b: i64 = tensor_new_2d(3, 2);
    tensor_set_flat(b, 0, f64_to_bits(7.0));
    tensor_set_flat(b, 1, f64_to_bits(8.0));
    tensor_set_flat(b, 2, f64_to_bits(9.0));
    tensor_set_flat(b, 3, f64_to_bits(10.0));
    tensor_set_flat(b, 4, f64_to_bits(11.0));
    tensor_set_flat(b, 5, f64_to_bits(12.0));
    return b;
}

fn check_new_2d_shape() -> i64 {
    let a: i64 = make_a();
    if tensor_ndim(a) != 2 { tensor_free(a); return 1; };
    if tensor_shape(a, 0) != 2 { tensor_free(a); return 2; };
    if tensor_shape(a, 1) != 3 { tensor_free(a); return 4; };
    if tensor_total(a) != 6 { tensor_free(a); return 8; };
    tensor_free(a);
    return 0;
}

fn check_matmul() -> i64 {
    let a: i64 = make_a();
    let b: i64 = make_b();
    if tensor_can_matmul_2d(a, b) != 1 { tensor_free(a); tensor_free(b); return 16; };
    let c: i64 = tensor_matmul(a, b);
    if c == 0 { tensor_free(a); tensor_free(b); return 32; };
    if tensor_ndim(c) != 2 { tensor_free(a); tensor_free(b); tensor_free(c); return 64; };
    if tensor_shape(c, 0) != 2 { tensor_free(a); tensor_free(b); tensor_free(c); return 128; };
    if tensor_shape(c, 1) != 2 { tensor_free(a); tensor_free(b); tensor_free(c); return 256; };
    if close(tensor_get_flat(c, 0), f64_to_bits(58.0), 1e-9) != 1 { tensor_free(a); tensor_free(b); tensor_free(c); return 512; };
    if close(tensor_get_flat(c, 1), f64_to_bits(64.0), 1e-9) != 1 { tensor_free(a); tensor_free(b); tensor_free(c); return 1024; };
    if close(tensor_get_flat(c, 2), f64_to_bits(139.0), 1e-9) != 1 { tensor_free(a); tensor_free(b); tensor_free(c); return 2048; };
    if close(tensor_get_flat(c, 3), f64_to_bits(154.0), 1e-9) != 1 { tensor_free(a); tensor_free(b); tensor_free(c); return 4096; };
    tensor_free(a);
    tensor_free(b);
    tensor_free(c);
    return 0;
}

fn check_transpose() -> i64 {
    let a: i64 = make_a();
    let at: i64 = tensor_transpose(a);
    if at == 0 { tensor_free(a); return 8192; };
    if tensor_shape(at, 0) != 3 { tensor_free(a); tensor_free(at); return 16384; };
    if tensor_shape(at, 1) != 2 { tensor_free(a); tensor_free(at); return 32768; };
    if close(tensor_get_flat(at, 0), f64_to_bits(1.0), 1e-9) != 1 { tensor_free(a); tensor_free(at); return 65536; };
    if close(tensor_get_flat(at, 1), f64_to_bits(4.0), 1e-9) != 1 { tensor_free(a); tensor_free(at); return 131072; };
    if close(tensor_get_flat(at, 4), f64_to_bits(3.0), 1e-9) != 1 { tensor_free(a); tensor_free(at); return 262144; };
    if close(tensor_get_flat(at, 5), f64_to_bits(6.0), 1e-9) != 1 { tensor_free(a); tensor_free(at); return 524288; };
    tensor_free(a);
    tensor_free(at);
    return 0;
}

fn check_bad_matmul_returns_zero() -> i64 {
    let a: i64 = tensor_new_2d(2, 3);
    let b: i64 = tensor_new_2d(4, 2);
    let c: i64 = tensor_matmul(a, b);
    tensor_free(a);
    tensor_free(b);
    if c != 0 { tensor_free(c); return 1048576; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = tensor_limitations();
    if str_index_of(s, "tensor_matmul") < 0 { return 2097152; };
    if str_index_of(s, "tensor_transpose") < 0 { return 4194304; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_2d_shape();
    fails = fails + check_matmul();
    fails = fails + check_transpose();
    fails = fails + check_bad_matmul_returns_zero();
    fails = fails + check_limitations();
    return fails;
}
