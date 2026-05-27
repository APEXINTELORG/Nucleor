// 09_ode.nr — Solve a simple first-order ODE with adaptive RK45.
// dy/dt = -k*y  (exponential decay)  with y(0) = 1, k = 0.5
// Analytic solution: y(t) = exp(-0.5 * t)

// `use std::*` would be the shorter form, but the use-std-* path has a
// known cfile-collection bug that drops rod-side C files from the clang
// link line. Explicit import composes the correct link set; tracked
// separately as a compiler issue.
import "stdlib/rods/ode.nr"
import "stdlib/rods/complex.nr"

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

fn decay_rhs(t: i64, y: i64) -> i64 {
    let dy: i64 = vec_new();
    let yval: i64 = vec_get(y, 0);
    let neg_half: i64 = f64(0, 0 - 500000);
    vec_push(dy, f64_mul(neg_half, yval));
    return dy;
}

fn main() -> i64 {
    let y0: i64 = vec_new();
    vec_push(y0, f64_from_int(1));
    let t0: i64 = f64_from_int(0);
    let t1: i64 = f64_from_int(2);
    let tol: i64 = f64(0, 1000);

    print("Solving dy/dt = -0.5*y, y(0) = 1, over [0, 2]");
    print(str_concat("Expected y(2) = exp(-1) = ", ex_f64_to_str(f64_exp(f64_from_int(0 - 1)))));

    let result: i64 = ode_rk45(decay_rhs, y0, t0, t1, tol);
    let n: i64 = vec_len(result);
    let y_final: i64 = vec_get(result, n - 1);
    print(str_concat("RK45 y(2)   = ", ex_f64_to_str(y_final)));
    return 0;
}
