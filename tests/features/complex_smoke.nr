// v0.8.133 stdlib/rods/complex.nr first test coverage.
//
// Complex number arithmetic via C FFI. Pre-v0.8.133 the rod
// shipped with no fixture — quantum simulation, FFT, and signal
// processing adopters all rely on it.
//
// Locks five textbook complex-arithmetic invariants:
//   1. i² == -1 (defining property of i)
//   2. |1+0i| == 1, |0+0i| == 0
//   3. Additive inverse: z + (-z) == 0
//   4. Conjugate product: (a+bi)·(a-bi) == a²+b² (real)
//   5. Euler's identity: e^(iπ) + 1 == 0  (the famous one)
//
// All comparisons use cx_approx_eq with eps = 1e-6.
//
// Expected: rc=0.

import "stdlib/rods/complex.nr"

// epsilon for cx_approx_eq — 1e-6 encoded via f64(0, 1) = 0.000001
fn eps() -> i64 { return f64(0, 1); }

fn check_i_squared_eq_neg_one() -> i64 {
    let i: i64 = cx_i();
    let i2: i64 = cx_mul(i, i);
    let neg_one: i64 = cx_from_real(f64_from_int(0 - 1));
    if cx_approx_eq(i2, neg_one, eps()) != 1 { return 1; };
    return 0;
}

fn check_one_magnitude() -> i64 {
    let one: i64 = cx_one();
    let mag: i64 = cx_abs(one);
    let target: i64 = f64_from_int(1);
    if rods_f64_eq(mag, target) != 1 {
        // Approx equality: |mag - 1| < eps
        let diff: i64 = f64_sub(mag, target);
        let abs_diff: i64 = f64_abs(diff);
        if rods_f64_lt(abs_diff, eps()) != 1 { return 2; };
    };
    return 0;
}

fn check_zero_magnitude() -> i64 {
    let z: i64 = cx_zero();
    let mag: i64 = cx_abs(z);
    let abs_mag: i64 = f64_abs(mag);
    if rods_f64_lt(abs_mag, eps()) != 1 { return 4; };
    return 0;
}

fn check_additive_inverse() -> i64 {
    // z = 3 + 4i; z + (-z) should be zero
    let z: i64 = cx_new(f64_from_int(3), f64_from_int(4));
    let neg_z: i64 = cx_neg(z);
    let sum: i64 = cx_add(z, neg_z);
    if cx_approx_eq(sum, cx_zero(), eps()) != 1 { return 8; };
    return 0;
}

fn check_conjugate_product() -> i64 {
    // (3+4i)·(3-4i) = 9 + 16 = 25, purely real
    let z: i64 = cx_new(f64_from_int(3), f64_from_int(4));
    let z_conj: i64 = cx_conj(z);
    let prod: i64 = cx_mul(z, z_conj);
    let target: i64 = cx_from_real(f64_from_int(25));
    if cx_approx_eq(prod, target, eps()) != 1 { return 16; };
    return 0;
}

fn check_eulers_identity() -> i64 {
    // e^(iπ) + 1 = 0  (Euler)
    // e^(iπ) = cx_exp(i*π) = cx_exp(cx_new(0, π))
    let pi: i64 = f64_pi();
    let i_pi: i64 = cx_new(f64_from_int(0), pi);
    let e_i_pi: i64 = cx_exp(i_pi);
    let result: i64 = cx_add(e_i_pi, cx_one());
    // Looser eps for transcendental: 1e-5 = f64(0, 10)
    let loose_eps: i64 = f64(0, 10);
    if cx_approx_eq(result, cx_zero(), loose_eps) != 1 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_i_squared_eq_neg_one();
    fails = fails + check_one_magnitude();
    fails = fails + check_zero_magnitude();
    fails = fails + check_additive_inverse();
    fails = fails + check_conjugate_product();
    fails = fails + check_eulers_identity();
    return fails;
}
