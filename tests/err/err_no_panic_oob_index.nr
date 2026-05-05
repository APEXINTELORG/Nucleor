// EXPECT: warning[RT-009]
// v0.8.295 R03-D2 Phase 1 — #[no_panic] body containing `%` fires RT-009.

#[no_panic]
fn risky_mod(a: i64, b: i64) -> i64 {
    return a % b;
}

fn main() -> i32 {
    let r: i64 = risky_mod(10, 3);
    return 0;
}
