// EXPECT: LAW-004 law declared without check
// Lane 3 (F-DIAG-006): LAW-004 had no negative test in tests/err/.

#[law(Associativity)]
fn add(a: i64, b: i64) -> i64 {
    return a + b;
}

fn main() -> i64 {
    return add(1, 2);
}
