// EXPECT: LAW-006 law signature mismatch
// Lane 3 (F-DIAG-006): LAW-006 had no negative test in tests/err/.

#[law(Idempotence)]
fn merge(a: i64, b: i64, c: i64) -> i64 {
    return a + b + c;
}

fn main() -> i64 {
    return merge(1, 2, 3);
}
