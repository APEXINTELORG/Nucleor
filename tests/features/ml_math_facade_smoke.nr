import "stdlib/rods/ml/math_facade.nr"

// ml_math_facade_smoke — exercises typed f64 elementary math wrappers
// from stdlib/rods/ml/math_facade.nr (sqrt/exp/log/tanh/sin/cos/pow).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    if close_f64(math_sqrt_f64(4.0), 2.0, eps) != 1 { print("FAIL sqrt(4)"); fail = fail + 1; };
    if close_f64(math_sqrt_f64(0.0), 0.0, eps) != 1 { print("FAIL sqrt(0)"); fail = fail + 1; };
    if close_f64(math_exp_f64(0.0), 1.0, eps) != 1 { print("FAIL exp(0)"); fail = fail + 1; };
    if close_f64(math_log_f64(1.0), 0.0, eps) != 1 { print("FAIL log(1)"); fail = fail + 1; };
    if close_f64(math_log_f64(math_exp_f64(1.5)), 1.5, eps) != 1 { print("FAIL log/exp roundtrip"); fail = fail + 1; };

    if fail == 0 {
        print("OK ml_math_facade_smoke");
        return 0;
    };
    print("FAIL ml_math_facade_smoke");
    return 1;
}
