// Probe: should panic with the v0.4.6 diagnostic.
extern fn __nucleor_f64_erf(x: f64) -> f64;

fn main() -> i64 {
    let r: f64 = __nucleor_f64_erf(1.0);
    return 0;
}
