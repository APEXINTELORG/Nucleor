// VER-7: golden error-bound test for stdlib/rods/optim.nr.
// minimize f(x) = (x-3)^2 (vector domain, dim 1); grad = 2*(x-3).
// gradient descent from x0=0 must reach the minimizer x=3.
import "stdlib/rods/optim.nr"
import "stdlib/rods/complex.nr"
fn grad(xv: i64) -> i64 {
    let g: i64 = vec_new();
    vec_push(g, f64_mul(f64_from_int(2), f64_sub(vec_get(xv, 0), f64_from_int(3))));
    return g;
}
fn main() -> i64 {
    let x0: i64 = vec_new(); vec_push(x0, f64_from_int(0));
    let res: i64 = opt_gd(grad, x0, f64(0, 100000), 2000);
    let xmin: i64 = vec_get(res, 0);
    if f64_gt(f64_abs(f64_sub(xmin, f64_from_int(3))), f64(0, 10000)) == 1 { print("FAIL: opt_gd\n"); return 1; }
    print("PASS: opt_gd minimizes (x-3)^2 at x=3\n");
    return 0;
}
