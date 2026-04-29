// EXPECT: error[TYP-005] receiver type `Vec<T>` has no method
// v0.4.127: typo'd Vec method names previously surfaced via my
// v0.4.106 lift as `error[TYP-005]: undefined function `vec_lenn()``
// — confusing because the user's source said `v.lenn()`, not
// anything starting with `vec_`. The lift now detects synthetic
// `vec_<method>` names from the kind 8 method-dispatch catch-all
// and shows the actual source-side method name plus a list of
// supported Vec methods. Same UX-fix family as v0.4.107 (primitive
// receiver TYP-007) and v0.4.123 (struct field TYP-015).

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    let r: i64 = v.lenn();
    print_int(r);
    0
}
