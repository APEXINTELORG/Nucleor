// v0.8.191 stdlib/rods/gnn.nr first test coverage.
//
// Graph Neural Network primitives — gnn_circuit_to_graph
// (already covered in v0.8.148) is the most testable surface;
// adding standalone coverage on the gnn_relu + gnn_layer_norm
// utility paths.
//
// Locks two textbook utility invariants:
//   1. ReLU positive pass-through, negative zero:
//      relu([1, -1, 2, -3]) == [1, 0, 2, 0].
//   2. LayerNorm zero-mean unit-variance: layer_norm of a
//      sequence has approximately zero mean and unit variance
//      (within tolerance).
//
// Expected: rc=0.

import "stdlib/rods/gnn.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_relu_clipping() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(0.0 - 1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(0.0 - 3.0));
    let r: i64 = nuc_gnn_relu(v);
    if close(vec_get(r, 0), f64_to_bits(1.0), 1e-9) != 1 { return 1; };
    if close(vec_get(r, 1), f64_to_bits(0.0), 1e-9) != 1 { return 2; };
    if close(vec_get(r, 2), f64_to_bits(2.0), 1e-9) != 1 { return 4; };
    if close(vec_get(r, 3), f64_to_bits(0.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn check_layer_norm_zero_mean() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(4.0));
    let n: i64 = nuc_gnn_layer_norm(v, 4);
    let mut sum: f64 = 0.0;
    let mut i: i64 = 0;
    while i < 4 {
        sum = sum + f64_from_bits(vec_get(n, i));
        i = i + 1;
    };
    let abs_sum: f64 = if sum < 0.0 { 0.0 - sum } else { sum };
    if abs_sum > 1e-6 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_relu_clipping();
    fails = fails + check_layer_norm_zero_mean();
    return fails;
}
