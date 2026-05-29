// VER-7: golden error-bound test for stdlib/rods/quad.nr.
// integral of x^2 over [0,1] = 1/3 (0.33333...); methods must match
// the analytical value within bound.
import "stdlib/rods/quad.nr"
import "stdlib/rods/complex.nr"
fn fx(x: i64) -> i64 { return f64_mul(x, x); }
fn main() -> i64 {
    let third: i64 = f64_div(f64_from_int(1), f64_from_int(3));
    let qs: i64 = quad_simpson(fx, f64_from_int(0), f64_from_int(1), 100);
    if f64_gt(f64_abs(f64_sub(qs, third)), f64(0, 1000)) == 1 { print("FAIL: quad_simpson\n"); return 1; }
    let qt: i64 = quad_trapezoid(fx, f64_from_int(0), f64_from_int(1), 2000);
    if f64_gt(f64_abs(f64_sub(qt, third)), f64(0, 2000)) == 1 { print("FAIL: quad_trapezoid\n"); return 1; }
    print("PASS: quad x^2 over [0,1] = 1/3\n");
    return 0;
}
