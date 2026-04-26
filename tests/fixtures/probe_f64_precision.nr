// Probe: f64 literal precision loss
// Expected per NUC-FEEDBACK-005 corrected: 0.7978845608028654 lowers to zero
fn main() -> i64 {
    let k1: f64 = 0.7978845608028654;
    println!("{}", k1);
    let k2: f64 = 0.797885;
    println!("{}", k2);
    let eps: f64 = 0.00000001;
    println!("{}", eps);
    let small: f64 = 0.000001;
    println!("{}", small);
    return 0;
}
