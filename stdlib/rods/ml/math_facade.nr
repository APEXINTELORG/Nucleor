// math_facade.nr - local naming shim over Nucleor f64 math builtins.
//
// Keep this shim narrow. Importing the full upstream typed math rod can pull
// unfinished special-function wrappers into unrelated ML examples.

fn math_exp_f64(x: f64) -> f64 {
    return exp(x);
}

fn math_log_f64(x: f64) -> f64 {
    return log(x);
}

fn math_sqrt_f64(x: f64) -> f64 {
    return sqrt(x);
}

fn math_tanh_f64(x: f64) -> f64 {
    if x > 20.0 { return 1.0; };
    if x < -20.0 { return -1.0; };
    let e2x: f64 = math_exp_f64(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
}
