// EXPECT: NUM-002 numeric literal out of range
// T1.1 Phase 10 (v0.2.319): verify the diagnostic fires when an
// integer literal exceeds the declared narrow type's range.
// 256 doesn't fit in u8; the compiler should warn (NUM-002) and
// the literal silently wraps to 0 at runtime per current semantics.
fn main() -> i64 {
    let x: u8 = 256;
    return x;
}
