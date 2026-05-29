// VER-7: golden error-bound test for stdlib/rods/ode.nr.
// dy/dt = -0.5*y, y(0)=1 over [0,2]; analytic y(2)=exp(-1)=0.367879.
import "stdlib/rods/ode.nr"
import "stdlib/rods/complex.nr"
fn decay(t: i64, y: i64) -> i64 {
    let dy: i64 = vec_new();
    vec_push(dy, f64_mul(f64(0, 0 - 500000), vec_get(y, 0)));
    return dy;
}
fn main() -> i64 {
    let y0: i64 = vec_new(); vec_push(y0, f64_from_int(1));
    let res: i64 = ode_rk4(decay, y0, f64_from_int(0), f64_from_int(2), f64(0, 10000));
    let yf: i64 = vec_get(res, vec_len(res) - 1);
    let expected: i64 = f64_exp(f64_from_int(0 - 1));
    if f64_gt(f64_abs(f64_sub(yf, expected)), f64(0, 5000)) == 1 { print("FAIL: ode_rk4\n"); return 1; }
    print("PASS: ode_rk4 y(2) = exp(-1)\n");
    return 0;
}
