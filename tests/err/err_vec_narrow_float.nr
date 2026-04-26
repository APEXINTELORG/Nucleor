// EXPECT: error[TYP-009]: narrow-float vector
// EXPECT: NUC-FEEDBACK-002
//
// v0.3.180: NUC-FEEDBACK-002 promoted from informational
// warning (parse-time print) to a hard type-check error
// (TYP-009). Pre-fix the warning could be ignored and adopters
// shipped silently-zero results from f32_add(v[0], v[1]) etc.
// Now the build fails with TYP-009 unless they switch to
// Vec<i64>+manual helpers, Vec<f64>, or Tensor::*.

fn main() -> i64 {
    let mut v: Vec<f32> = Vec::new();
    v.push(1.0f32);
    return 0;
}
