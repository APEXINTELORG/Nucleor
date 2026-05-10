// EXPECT: DIAG-001 unknown diagnostic-code suppression
// Lane 3 (F-DIAG-006): DIAG-001 had no negative test.
// Deny promotes the normally-warning unknown-code diagnostic for tests/err.

#[deny(DIAG-001)]
#[allow(NOT-A-REAL-CODE)]
fn main() -> i64 {
    return 0;
}
