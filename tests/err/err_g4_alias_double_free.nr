// EXPECT: OWN-G4-USE-AFTER-DROP
// Lane 2 audit fix (G4-FN-1, 2026-05-08): aliased-handle
// double-free. Pre-fix `let alias: Vec<i64> = v; vec_free(alias);
// vec_free(v);` was silent because the freed flag was tracked
// on binding-name, not heap location. Now: the alias transfer marks
// the source moved/freed, so the second free is rejected before it
// can release the same allocation twice.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    let alias: Vec<i64> = v;
    vec_free(alias);
    vec_free(v);
    0
}
