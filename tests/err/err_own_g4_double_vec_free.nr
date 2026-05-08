// EXPECT: OWN-G4-USE-AFTER-DROP use of 'v' after manual free
// RFC-0062 G-4 Phase 2b/3/4 — double-free is a special case of
// use-after-drop: the second `vec_free(v)` call's arg-walk reads
// `v` while the freed flag is set, so OWN-G4-USE-AFTER-DROP fires
// before the second free runs. Lock-in for the double-free path.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    vec_free(v);
    vec_free(v);
    0
}
