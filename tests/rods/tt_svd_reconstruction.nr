// tt_svd_reconstruction.nr — Audit fix F-MATH-001 (CRITICAL, 2026-05-08)
// regression coverage. Verifies the real TT-SVD implementation
// reconstructs the input tensor when max_rank >= true_rank.
//
// Prior code returned identity-shaped placeholder cores; reconstructing
// G1 ×_3 G2 ×_3 G3 produced garbage. The new implementation runs two
// truncated SVDs (via the symmetric-Jacobi-on-AtA helper) and gives
// G1 G2 G3 such that the contracted reconstruction matches the input
// to within the truncation rank.
//
// We use a rank-1 outer-product tensor X[i,j,k] = a[i] * b[j] * c[k]
// where TT-SVD with max_rank >= 1 must reconstruct exactly. We sample
// a couple of slices of the cores and confirm the reconstructed value
// matches the analytic value to ~1e-10 (Jacobi precision).
//
// Tolerance documented: 1e-9 absolute on a [-2, 2] range tensor.
import "stdlib/rods/tensor_decomp.nr"

fn make_outer_222() -> Vec<i64> {
    // a = [1, 2], b = [1, -1], c = [2, 3]
    // X[i, j, k] = a[i] * b[j] * c[k]
    // X[0,0,0]=2  X[0,0,1]=3  X[0,1,0]=-2  X[0,1,1]=-3
    // X[1,0,0]=4  X[1,0,1]=6  X[1,1,0]=-4  X[1,1,1]=-6
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

fn approx(a: f64, b: f64, tol: f64) -> i64 {
    let d: f64 = a - b;
    if d < 0.0 - tol { return 0; };
    if d > tol { return 0; };
    return 1;
}

fn main() -> i64 {
    let mut fails: i64 = 0;

    // Rank-1 outer product → TT decomposition with bond ranks 1
    // must reconstruct exactly. With max_rank=2 (full rank cap), it
    // must reconstruct exactly.
    let x: Vec<i64> = make_outer_222();
    let h: i64 = tdecomp_tt_svd_3d_max_rank(x, 2, 2, 2, 2);
    if h == 0 {
        print("FAIL tt_svd_reconstruction: handle 0");
        return 1;
    };

    // Header: [r1, r2, g1s, g2s, g3s, padding, G1..., G2..., G3...]
    let r1: i64 = vec_get(h, 0);
    let r2: i64 = vec_get(h, 1);
    let g1s: i64 = vec_get(h, 2);
    let g2s: i64 = vec_get(h, 3);
    let g3s: i64 = vec_get(h, 4);

    if r1 < 1 { fails = fails + 1; print("FAIL tt_svd: r1 < 1"); };
    if r2 < 1 { fails = fails + 1; print("FAIL tt_svd: r2 < 1"); };
    if g1s != 2 * r1 { fails = fails + 1; print("FAIL tt_svd: g1s mismatch"); };
    if g2s != r1 * 2 * r2 { fails = fails + 1; print("FAIL tt_svd: g2s mismatch"); };
    if g3s != r2 * 2 { fails = fails + 1; print("FAIL tt_svd: g3s mismatch"); };

    // Reconstruct X[0,0,0] via the cores:
    //   X[i,j,k] = sum_{a,b} G1[i, a] * G2[a, j, b] * G3[b, k]
    // (G1 stride [d1, r1], G2 stride [r1, d2, r2], G3 stride [r2, d3])
    let g1_off: i64 = 6;
    let g2_off: i64 = g1_off + g1s;
    let g3_off: i64 = g2_off + g2s;
    let two: i64 = 2;

    // Sum over a in [0, r1), b in [0, r2) of G1[i,a]*G2[a,j,b]*G3[b,k]
    // for (i, j, k) = (0, 0, 0): expect 2.0
    let mut acc: f64 = 0.0;
    let mut a: i64 = 0;
    while a < r1 {
        let mut b: i64 = 0;
        while b < r2 {
            let g1_v: f64 = f64_from_bits(vec_get(h, g1_off + a));
            // G2[a, 0, b] -> a*d2*r2 + 0*r2 + b
            let g2_v: f64 = f64_from_bits(vec_get(h, g2_off + a * two * r2 + b));
            // G3[b, 0] -> b*d3 + 0
            let g3_v: f64 = f64_from_bits(vec_get(h, g3_off + b * two));
            acc = acc + g1_v * g2_v * g3_v;
            b = b + 1;
        };
        a = a + 1;
    };
    if approx(acc, 2.0, 0.000000001) != 1 {
        fails = fails + 1;
        print("FAIL tt_svd: X[0,0,0] != 2.0 to 1e-9");
    };

    // (1, 1, 1): expect a[1]*b[1]*c[1] = 2*-1*3 = -6
    let mut acc2: f64 = 0.0;
    let mut a2: i64 = 0;
    while a2 < r1 {
        let mut b2: i64 = 0;
        while b2 < r2 {
            let g1_v: f64 = f64_from_bits(vec_get(h, g1_off + r1 + a2));
            let g2_v: f64 = f64_from_bits(vec_get(h, g2_off + a2 * two * r2 + r2 + b2));
            let g3_v: f64 = f64_from_bits(vec_get(h, g3_off + b2 * two + 1));
            acc2 = acc2 + g1_v * g2_v * g3_v;
            b2 = b2 + 1;
        };
        a2 = a2 + 1;
    };
    if approx(acc2, 0.0 - 6.0, 0.000000001) != 1 {
        fails = fails + 1;
        print("FAIL tt_svd: X[1,1,1] != -6.0 to 1e-9");
    };

    if fails == 0 { print("OK tt_svd_reconstruction"); };
    return fails;
}
