// v0.7.39 negative fixture — pattern-destructure in fn parameter halts
// cleanly (was wrong-class NR020 expected `:`, got identifier).
fn h((a, b): (i64, i64)) -> i64 { return a + b; }
fn main() -> i64 {
    return 0;
}
