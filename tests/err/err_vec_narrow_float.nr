// EXPECT: error[TYP-009]: narrow-float vector
// EXPECT: NUC-FEEDBACK-002
//
// v0.3.180: NUC-FEEDBACK-002 promoted from informational
// warning to a hard type-check error (TYP-009).
//
// v0.3.204: NUC-FEEDBACK-002 deeper fix -- Vec<f32> downgraded
// (round-trip via f32_from_bits verified in t462). f16/bf16/
// f8eXmY still hard-error because they have no runtime pack/
// unpack helpers; this fixture now exercises Vec<f16> instead
// of Vec<f32>.

fn main() -> i64 {
    let mut v: Vec<f16> = Vec::new();
    v.push(1);
    return 0;
}
