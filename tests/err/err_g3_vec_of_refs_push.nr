// EXPECT: ALIAS-G3-VEC-OF-REFS vec_push
// RFC-0062 G-3 Phase 3 — heap-aliasing per-fn analysis. The
// syntactic borrow tracker doesn't follow elements through
// `Vec<&T>`, so `vec_push(v, &x)` followed by `vec_push(v, &x)`
// can leave aliased &T pointing at the same T while the tracker
// sees no overlap. ALIAS-G3-VEC-OF-REFS fires at every call site
// where vec_push / vec_insert lands on a Vec<&T> binding. Phase
// 4 lock-in: registered at error severity in is_error_code.
fn main() -> i32 {
    let x: i64 = 1;
    let y: i64 = 2;
    let mut v: Vec<&i64> = Vec::new();
    vec_push(v, &x);
    vec_push(v, &y);
    0
}
