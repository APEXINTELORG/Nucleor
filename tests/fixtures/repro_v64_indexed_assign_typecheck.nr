// repro_v64_indexed_assign_typecheck.nr
//
// v0.4.64 NUC-FEEDBACK silent-coerce close for indexed assignment.
// Pre-fix `v[0] = "string"` on `let v: Vec<i64>` silently stored
// the str pointer as i64. Adopters writing canonical Rust (which
// errors on type mismatch) got a quiet wrong value.
//
// v0.4.64 extends the kind-21 (assign) handler in type_check_stmt
// to recognize kind-10 (indexing) on a kind-3 var ref and validate
// RHS against the Vec's element type via strip_container_one_level.
// Source-scan fallback recovers Vec<T> from declarations even when
// tenv stores "" (same trick as v0.4.61).

fn main() -> i64 {
    let mut v: Vec<i64> = vec![1, 2, 3];
    v[0] = "string";   // TYP-009 expected
    println!("{}", v[0]);
    return 0;
}
