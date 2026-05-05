// v0.8.163 stdlib/rods/stats.nr first test coverage.
//
// Statistics primitives: mean, median, variance, stddev,
// linear regression. Pre-v0.8.163: zero coverage.
//
// Locks five textbook statistical invariants on closed-form
// inputs:
//   1. **Mean** of [1,2,3,4,5] == 3.
//   2. **Median** of [1,2,3,4,5] == 3 (odd-length: middle).
//   3. **Variance** of [1,2,3,4,5] == 2 (population, n divisor)
//      OR == 2.5 (sample, n-1 divisor). We accept either by
//      checking >1.5 and <3.
//   4. **Linear regression** on perfectly linear data
//      (y = 2x + 1) → slope ≈ 2, intercept ≈ 1, R² ≈ 1.
//   5. **Correlation** of perfectly linear data ≈ 1.
//
// Expected: rc=0.

import "stdlib/rods/stats.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_v(vals: Vec<i64>) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(vals) {
        v.push(f64_to_bits(vec_get(vals, i) as f64));
        i = i + 1;
    };
    return v;
}

fn check_mean() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 1;
    while i <= 5 { v.push(f64_to_bits(i as f64)); i = i + 1; };
    let m: i64 = stat_mean(v);
    if close(m, f64_to_bits(3.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_median() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 1;
    while i <= 5 { v.push(f64_to_bits(i as f64)); i = i + 1; };
    let m: i64 = stat_median(v);
    if close(m, f64_to_bits(3.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_variance() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 1;
    while i <= 5 { v.push(f64_to_bits(i as f64)); i = i + 1; };
    let var_bits: i64 = stat_var(v);
    let var_val: f64 = f64_from_bits(var_bits);
    // Accept either pop (2.0) or sample (2.5)
    if var_val < 1.5 { return 4; };
    if var_val > 3.0 { return 8; };
    return 0;
}

fn check_linear_regression() -> i64 {
    // y = 2x + 1 on x in [1..5]
    let mut x: Vec<i64> = Vec::new();
    let mut y: Vec<i64> = Vec::new();
    let mut i: i64 = 1;
    while i <= 5 {
        x.push(f64_to_bits(i as f64));
        y.push(f64_to_bits((2 * i + 1) as f64));
        i = i + 1;
    };
    let h: i64 = stat_linreg(x, y);
    if h == 0 { return 16; };
    let slope: i64 = stat_linreg_slope(h);
    if close(slope, f64_to_bits(2.0), 1e-9) != 1 { return 32; };
    let intercept: i64 = stat_linreg_intercept(h);
    if close(intercept, f64_to_bits(1.0), 1e-9) != 1 { return 64; };
    let r2: i64 = stat_linreg_r2(h);
    if close(r2, f64_to_bits(1.0), 1e-9) != 1 { return 128; };
    return 0;
}

fn check_correlation() -> i64 {
    let mut x: Vec<i64> = Vec::new();
    let mut y: Vec<i64> = Vec::new();
    let mut i: i64 = 1;
    while i <= 5 {
        x.push(f64_to_bits(i as f64));
        y.push(f64_to_bits((2 * i + 1) as f64));
        i = i + 1;
    };
    let r: i64 = stat_corr(x, y);
    if close(r, f64_to_bits(1.0), 1e-6) != 1 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mean();
    fails = fails + check_median();
    fails = fails + check_variance();
    fails = fails + check_linear_regression();
    fails = fails + check_correlation();
    return fails;
}
