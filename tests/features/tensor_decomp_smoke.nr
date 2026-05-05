// v0.8.182 stdlib/rods/tensor_decomp.nr first test coverage.
//
// Tensor decompositions — Kronecker product, Khatri-Rao product
// (CP-ALS / TT-SVD are heavier; deferred to dedicated ML/ship).
// Pre-v0.8.182: zero coverage.
//
// Locks two textbook product invariants:
//   1. **Kronecker product 2×2 × 2×2** → 4×4 result with the
//      classic structure:
//
//        A = [1 2; 3 4],  B = [5 6; 7 8]
//        A ⊗ B = [
//          5  6 10 12
//          7  8 14 16
//         15 18 20 24
//         21 24 28 32
//        ]
//
//      Verify a few key cells.
//
//   2. **Khatri-Rao 2×2 ⊙ 2×2** → 4×2 (I*J × R):
//      column 0: [1*5, 1*7, 3*5, 3*7] = [5, 7, 15, 21]
//
// Expected: rc=0.

import "stdlib/rods/tensor_decomp.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_2x2(v0: f64, v1: f64, v2: f64, v3: f64) -> Vec<i64> {
    let mut m: Vec<i64> = Vec::new();
    m.push(f64_to_bits(v0));
    m.push(f64_to_bits(v1));
    m.push(f64_to_bits(v2));
    m.push(f64_to_bits(v3));
    return m;
}

fn check_kronecker() -> i64 {
    let a: Vec<i64> = make_2x2(1.0, 2.0, 3.0, 4.0);
    let b: Vec<i64> = make_2x2(5.0, 6.0, 7.0, 8.0);
    let c: i64 = tdecomp_kronecker(a, b, 2, 2, 2, 2);
    if c == 0 { return 1; };
    // C is 4x4, row-major. Cell (0,0) = A[0,0]*B[0,0] = 1*5 = 5
    if close(vec_get(c, 0), f64_to_bits(5.0), 1e-9) != 1 { return 2; };
    // Cell (0,1) = A[0,0]*B[0,1] = 1*6 = 6
    if close(vec_get(c, 1), f64_to_bits(6.0), 1e-9) != 1 { return 4; };
    // Cell (0,2) = A[0,1]*B[0,0] = 2*5 = 10
    if close(vec_get(c, 2), f64_to_bits(10.0), 1e-9) != 1 { return 8; };
    // Cell (3,3) = A[1,1]*B[1,1] = 4*8 = 32 (bottom-right)
    if close(vec_get(c, 15), f64_to_bits(32.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn check_khatri_rao() -> i64 {
    let a: Vec<i64> = make_2x2(1.0, 0.0, 3.0, 0.0); // 2x2, columns are [1,3] and [0,0]
    let b: Vec<i64> = make_2x2(5.0, 0.0, 7.0, 0.0); // columns [5,7] and [0,0]
    // Khatri-Rao: column-wise Kronecker.
    // C is (I*J)×R = 4×2. Storage: row-major.
    // Column 0: kron([1,3], [5,7]) = [5, 7, 15, 21]
    let c: i64 = tdecomp_khatri_rao(a, b, 2, 2, 2);
    if c == 0 { return 32; };
    // Column-0 entries at rows 0..3:
    // Layout per impl: C[(i*J + j) * R + r]
    // (i=0,j=0,r=0): C[0]=A[0,0]*B[0,0]=1*5=5
    // (i=0,j=1,r=0): C[2]=A[0,0]*B[1,0]=1*7=7
    // (i=1,j=0,r=0): C[4]=A[1,0]*B[0,0]=3*5=15
    // (i=1,j=1,r=0): C[6]=A[1,0]*B[1,0]=3*7=21
    if close(vec_get(c, 0), f64_to_bits(5.0), 1e-9) != 1 { return 64; };
    if close(vec_get(c, 2), f64_to_bits(7.0), 1e-9) != 1 { return 128; };
    if close(vec_get(c, 4), f64_to_bits(15.0), 1e-9) != 1 { return 256; };
    if close(vec_get(c, 6), f64_to_bits(21.0), 1e-9) != 1 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_kronecker();
    fails = fails + check_khatri_rao();
    return fails;
}
