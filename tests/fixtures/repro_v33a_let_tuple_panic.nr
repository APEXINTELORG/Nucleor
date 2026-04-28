// v0.4.33a silent-fall-through closure: `let (a, b) = (5, 7);` printed
// ERROR but emitted a placeholder let-stmt and continued — adopter's
// `a` and `b` were never bound, downstream uses either link-failed
// (with confusing message) or referenced unrelated shadows. Now panics.
// EXPECT: panic
fn main() -> i64 {
    let (a, b) = (5, 7);
    return a + b;
}
