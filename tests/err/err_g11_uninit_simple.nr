// EXPECT: TYP-008 binding declared without initializer
// RFC-0062 G-11 Phase 1 — locks in MS-7 (uninitialized read)
// rejection. Phase 1 finding: TYP-008 already covers the simple
// case; this fixture exists to lock that behavior so future
// refactors don't regress the diagnostic.

fn main() -> i64 {
    let mut x: i64;     // ERROR: declared without initializer
    x = 7;
    return x;
}
