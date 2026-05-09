// EXPECT: DIAG-001 unknown code in #[allow(...)]
// Lane 3 (F-DIAG-006): DIAG-001 had no negative test.
// `#[allow(NOT-A-REAL-CODE)]` should warn that the code is unknown.

#[allow(NOT-A-REAL-CODE)]
fn main() -> i64 {
    return 0;
}
