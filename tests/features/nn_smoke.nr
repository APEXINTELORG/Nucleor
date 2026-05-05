// v0.8.226 stdlib/rods/nn.nr first test coverage.
//
// Neural-network training surface — dense layers, activations,
// Adam, attention, ensemble. Pre-v0.8.226: zero coverage on the
// standalone rod (sister to activation2.nr which is the
// transformer-flavored set).
//
// Locks four invariants on the activation + vec utility surface:
//
//   1. **ReLU clamps negatives to 0** — relu([-3, 5, -1]) →
//      [0, 5, 0].
//   2. **Sigmoid(0) == 0.5** — 1/(1+e⁰) = 1/2.
//   3. **vec_concat preserves length and order** — concat
//      ([1,2], [3,4,5]) → length 5, [1,2,3,4,5].
//   4. **vec_slice extracts subrange** — slice([10,20,30,40,50],
//      1, 3) → [20, 30, 40].
//
// Heavier surfaces (dense + Adam + attention) need careful
// tensor setup; deferred to dedicated training fixtures.
//
// Expected: rc=0.

import "stdlib/rods/nn.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_relu_clamps_negatives() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0 - 3.0));
    v.push(f64_to_bits(5.0));
    v.push(f64_to_bits(0.0 - 1.0));
    let r: i64 = nuc_nn_relu(v);
    if close(vec_get(r, 0), f64_to_bits(0.0), 1e-12) != 1 { return 1; };
    if close(vec_get(r, 1), f64_to_bits(5.0), 1e-12) != 1 { return 2; };
    if close(vec_get(r, 2), f64_to_bits(0.0), 1e-12) != 1 { return 4; };
    return 0;
}

fn check_sigmoid_zero() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    let s: i64 = nuc_nn_sigmoid(v);
    if close(vec_get(s, 0), f64_to_bits(0.5), 1e-12) != 1 { return 8; };
    return 0;
}

fn check_vec_concat() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(1.0));
    a.push(f64_to_bits(2.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(3.0));
    b.push(f64_to_bits(4.0));
    b.push(f64_to_bits(5.0));
    let c: i64 = nuc_nn_vec_concat(a, b);
    if vec_len(c) != 5 { return 16; };
    if close(vec_get(c, 0), f64_to_bits(1.0), 1e-12) != 1 { return 32; };
    if close(vec_get(c, 4), f64_to_bits(5.0), 1e-12) != 1 { return 64; };
    return 0;
}

fn check_vec_slice() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(10.0));
    v.push(f64_to_bits(20.0));
    v.push(f64_to_bits(30.0));
    v.push(f64_to_bits(40.0));
    v.push(f64_to_bits(50.0));
    let s: i64 = nuc_nn_vec_slice(v, 1, 3);
    if vec_len(s) != 3 { return 128; };
    if close(vec_get(s, 0), f64_to_bits(20.0), 1e-12) != 1 { return 256; };
    if close(vec_get(s, 1), f64_to_bits(30.0), 1e-12) != 1 { return 512; };
    if close(vec_get(s, 2), f64_to_bits(40.0), 1e-12) != 1 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_relu_clamps_negatives();
    fails = fails + check_sigmoid_zero();
    fails = fails + check_vec_concat();
    fails = fails + check_vec_slice();
    return fails;
}
