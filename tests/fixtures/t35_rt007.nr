// T3.5 (v0.3.3) RT-007 fixture — used by the verify gate to
// assert the deadline-safety check warns when a #[deadline]
// fn lacks both #[no_alloc] and #[no_panic].
//
// Fixture: bare #[deadline = 100000] fn with no companion
// attribute. Estimator should NOT fire RT-004 (the body is
// trivial), but the cross-check should fire RT-007.

#[deadline = 100000]
fn unguarded(x: i64) -> i64 {
    return x + 1;
}

fn main() -> i64 {
    return unguarded(0);
}
