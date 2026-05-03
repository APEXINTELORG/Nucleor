// v0.6.52 (probe finding 2026-05-02-negative-zero-const-fold-loses-sign +
// sister 2026-05-02-negative-zero-const-and-unary-neg-both-lose-sign):
// canonical IEEE 754 negative-zero sign bit preserved through unary minus.
// Pre-fix `let z: f64 = -0.0; print_f64(1.0 / z)` printed `+inf`; now `-inf`.
fn main() -> i32 {
    let z: f64 = -0.0;
    let inv: f64 = 1.0 / z;
    print_f64(inv);
    let x: f64 = 5.0;
    let nx: f64 = -x;
    print_f64(nx);
    let y: f32 = 3.0;
    let ny: f32 = -y;
    print_f64(ny as f64);
    return 0;
}
