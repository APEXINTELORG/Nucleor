// EXPECT: LAW-001 unknown law name
// Lane 3 (F-DIAG-006): LAW-001 had no negative test in tests/err/.

#[law(NotARealLaw)]
fn main() -> i64 {
    return 0;
}
