// EXPECT: error[TYP-008] type mismatch for binding 'r'
// v0.4.158: kind-8 type_expr now returns the receiver Vec
// type for clone/sort/reverse/map/filter/collect/take/skip/
// chain/step_by — pre-fix all of these fell to the catch-all
// `return ""`, which broke the v0.4.139 cascade for any
// chained call. `let r: i64 = v.clone().push(N);` silently
// bound r=0 because the outer push saw recv_t="" instead of
// "Vec<i64>", so the v0.4.139 void-mutator route didn't fire.
// Now the inner clone returns "Vec<i64>", outer push returns
// "void" (per v0.4.139), and types_compatible fails the
// `let r: i64 = void` binding. s1-only fix.

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    v.push(10);
    let r: i64 = v.clone().push(20);
    print_int(r);
    0
}
