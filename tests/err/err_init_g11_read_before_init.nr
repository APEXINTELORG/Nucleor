// EXPECT: INIT-G11-READ-BEFORE-INIT read of 'x' before it is definitely assigned
// RFC-0062 G-11 Phase 2b/3/4 — `let mut x: i64;` declared without
// initializer, then read before any assignment. The DA flow
// analysis sets `__init_x = 0` at the let-decl; the subsequent
// read finds the flag still 0 and emits INIT-G11-READ-BEFORE-INIT
// at error severity. Replaces the old TYP-008 lock-in for this
// shape (TYP-008 now narrows to immutable no-init only).
fn main() -> i64 {
    let mut x: i64;
    return x;
}
