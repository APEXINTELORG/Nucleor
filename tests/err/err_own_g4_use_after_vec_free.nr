// EXPECT: OWN-G4-USE-AFTER-DROP use of 'v' after manual free
// RFC-0062 G-4 Phase 2b/3/4 — IR-level use-after-drop. Today
// `Vec<T>` / `HashMap<K,V>` / `String` are treated as Copy by
// the move-state tracker (i64-everywhere ABI: the binding is
// just an i64 handle), so `vec_free(v); v.push(7);` slipped past
// OWN-001. Phase 2b adds a separate freed flag set at the
// manual-free call site; subsequent reads emit
// OWN-G4-USE-AFTER-DROP at error severity.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    vec_push(v, 2);
    vec_free(v);
    vec_push(v, 7);
    0
}
