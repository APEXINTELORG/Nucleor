// EXPECT: error[TYP-011] `?` operator on binding `x` of type `i64`
// v0.4.157: extends v0.4.54's `?`-on-non-Result check (kind-7
// receiver only) to kind-3 (var-ref) receivers. Pre-fix
// `let x: i64 = 5; let y = x?;` matched only the kind-7 call
// branch in the existing check, so x's `?` lower emitted the
// same `vec_get(val_r, 0)` tag-extract as the pre-v0.4.54 era
// and SIGSEGVed at runtime when the i64 value was dereferenced
// as a pointer. Same TYP-011 family — just a tenv lookup
// (binding type) instead of sigs (fn rtype). s1-only fix
// (tools_suite has no `?` handling in type_expr).

fn main() -> i32 {
    let x: i64 = 5;
    let y = x?;
    print_int(y);
    0
}
