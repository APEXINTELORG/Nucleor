// Negative fixture for EFF-001 — pure fn calling alloc helper.
//
// Pre-v0.8.323 the syntactic check only matched literal Vec::new /
// Box::new constructors; non-constructor allocators like vec_push,
// str_concat, hashmap_insert silently passed even though they
// allocate. v0.8.323 (RFC-0063 Phase 1.5) extends the check to
// detect calls to known-impure stdlib helpers and fires EFF-001
// with the specific callee in the message.
//
// Expected: error[EFF-001] mentioning vec_push.

pure fn impure_via_vec_push(v: Vec<i64>) -> i64 {
    vec_push(v, 42);
    return vec_len(v);
}

fn main() -> i64 {
    let v: Vec<i64> = Vec::new();
    return impure_via_vec_push(v);
}
