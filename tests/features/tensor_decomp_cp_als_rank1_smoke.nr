// Audit F-MATH-002: CP-ALS must use a full dense Gram solve, not only
// diagonal division. A rank-1 2x2x2 tensor should reconstruct from the
// returned factors after ALS converges.

import "stdlib/rods/tensor_decomp.nr"

fn approx(a: f64, b: f64, tol: f64) -> i64 {
    let d: f64 = a - b;
    if d < 0.0 - tol { return 0; };
    if d > tol { return 0; };
    return 1;
}

fn make_outer_222() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(0.0 - 2.0));
    v.push(f64_to_bits(0.0 - 3.0));
    v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(6.0));
    v.push(f64_to_bits(0.0 - 4.0));
    v.push(f64_to_bits(0.0 - 6.0));
    return v;
}

fn main() -> i64 {
    let x: Vec<i64> = make_outer_222();
    let factors: i64 = tdecomp_cp_als(x, 2, 2, 2, 1, 30);
    if factors == 0 { return 1; };
    if vec_len(factors) != 6 { return 2; };

    let mut idx: i64 = 0;
    while idx < 8 {
        let i: i64 = idx / 4;
        let rem: i64 = idx - i * 4;
        let j: i64 = rem / 2;
        let k: i64 = rem - j * 2;
        let a: f64 = f64_from_bits(vec_get(factors, i));
        let b: f64 = f64_from_bits(vec_get(factors, 2 + j));
        let c: f64 = f64_from_bits(vec_get(factors, 4 + k));
        let recon: f64 = a * b * c;
        let want: f64 = f64_from_bits(vec_get(x, idx));
        if approx(recon, want, 0.001) != 1 {
            print("FAIL cp_als rank1 reconstruction");
            return 4;
        };
        idx = idx + 1;
    };
    return 0;
}
