// EXPECT: OWN-G4-USE-AFTER-DROP vec_get
// Lane 2 audit fix (G4-B-1, 2026-05-08): use-after-free behind
// `as` cast. Pre-fix, `vec_free(v); let n: i32 = vec_get(v, 0)
// as i32;` slipped past G-4 because check_expr's kind-99 (cast)
// recursion didn't walk the cast operand. Now: kind-99 walks
// the operand so the inner call's arg-walk hits the IDENT and
// fires OWN-G4-USE-AFTER-DROP.
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    vec_free(v);
    let n: i32 = vec_get(v, 0) as i32;
    n
}
