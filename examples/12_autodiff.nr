// 12_autodiff.nr — Reverse-mode automatic differentiation.
// Function:  f(x) = sin(x²) + x
// Derivative: f'(x) = 2x·cos(x²) + 1
// At x = 1.5: f(1.5) = sin(2.25) + 1.5 ≈ 2.278
//             f'(1.5) = 3·cos(2.25) + 1 ≈ -0.881

use std::autodiff;
use std::complex;

fn ex_int_to_str(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = ""; let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 { let d: i64 = v - (v / 10) * 10; s = str_concat(str_substring("0123456789", d, d + 1), s); v = v / 10; };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn ex_f64_to_str(val: i64) -> str {
    let is_neg: i64 = f64_lt(val, f64_from_int(0));
    let av: i64 = f64_abs(val);
    let ip: i64 = f64_to_int(f64_floor(av));
    let frac: i64 = f64_sub(av, f64_from_int(ip));
    let fs: i64 = f64_to_int(f64_floor(f64_mul(frac, f64_from_int(1000000))));
    let mut fstr: str = ex_int_to_str(fs);
    while str_len(fstr) < 6 { fstr = str_concat("0", fstr); };
    let mut r: str = str_concat(ex_int_to_str(ip), str_concat(".", fstr));
    if is_neg == 1 { r = str_concat("-", r); };
    return r;
}

fn main() -> i64 {
    ad_reset();
    let x: i64 = ad_var(f64(1, 500000));    // x = 1.5
    let xsq: i64 = ad_mul(x, x);
    let sin_xsq: i64 = ad_sin(xsq);
    let f: i64 = ad_add(sin_xsq, x);

    let value: i64 = ad_value(f);
    let grad: i64 = ad_grad(f, x);

    print("f(x) = sin(x²) + x  evaluated at x = 1.5");
    print(str_concat("  f(1.5)  = ", ex_f64_to_str(value)));
    print(str_concat("  f'(1.5) = ", ex_f64_to_str(grad)));
    print("  expected: f(1.5) ≈ 2.278, f'(1.5) ≈ -0.881");
    return 0;
}
