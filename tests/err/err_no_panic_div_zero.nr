// EXPECT: warning[RT-009]
// v0.8.295 R03-D2 Phase 1 — #[no_panic] body containing `/` fires RT-009.
//
// Pre-v0.8.295 this compiled cleanly (the no_panic checker only
// scanned for explicit panic-name calls, not implicit panic
// sources). Post-v0.8.295 the body scan flags integer division
// as a warning.
//
// Adopter who has proven the divisor is non-zero suppresses with
// `#[allow_fn(RT-009)]` per Phase 1's allow-list mechanism.

#[no_panic]
fn risky_divide(a: i64, b: i64) -> i64 {
    return a / b;
}

fn main() -> i32 {
    let r: i64 = risky_divide(10, 2);
    return 0;
}
