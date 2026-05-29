// VER-7: golden error-bound test for stdlib/rods/root.nr.
// f(x) = x^2 - 2 over [1,2]; every method must converge to sqrt(2)
// (1.4142135...) within 1e-3. Anchored to the analytical root.
import "stdlib/rods/root.nr"
import "stdlib/rods/complex.nr"

fn fx(x: i64) -> i64 { return f64_sub(f64_mul(x, x), f64_from_int(2)); }
fn dfx(x: i64) -> i64 { return f64_mul(f64_from_int(2), x); }

fn within(got: i64, want: i64, tol: i64) -> i64 {
    if f64_gt(f64_abs(f64_sub(got, want)), tol) == 1 { return 0; }
    return 1;
}

fn main() -> i64 {
    let sqrt2: i64 = f64_sqrt(f64_from_int(2));
    let tol: i64 = f64(0, 1000);        // solver tolerance 0.001
    let bound: i64 = f64(0, 2000);      // assertion bound 0.002
    let rb: i64 = root_bisection(fx, f64_from_int(1), f64_from_int(2), tol);
    if within(rb, sqrt2, bound) == 0 { print("FAIL: root_bisection\n"); return 1; }
    let rn: i64 = root_newton(fx, dfx, f64_from_int(2), tol);
    if within(rn, sqrt2, bound) == 0 { print("FAIL: root_newton\n"); return 1; }
    let rs: i64 = root_secant(fx, f64_from_int(1), f64_from_int(2), tol);
    if within(rs, sqrt2, bound) == 0 { print("FAIL: root_secant\n"); return 1; }
    print("PASS: root_* converge to sqrt(2) within 2e-3\n");
    return 0;
}
