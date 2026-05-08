// RFC-0062 G-4 Phase 2b/3/4 — positive lock-in. Manual `vec_free`
// at end of scope (no subsequent reads) does NOT trigger
// OWN-G4-USE-AFTER-DROP. The freed flag is set after the call but
// is never checked because nothing reads `v` after the free. This
// is the canonical adopter-correct pattern that should still
// compile cleanly post-Phase 4 promotion.

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    vec_push(v, 2);
    print_int(vec_get(v, 0) as i32);
    vec_free(v);
    0
}
