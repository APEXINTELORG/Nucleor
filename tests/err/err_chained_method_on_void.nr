// EXPECT: error[TYP-023] chained method `.len()` on a void-returning receiver
// v0.4.139: chained method call on a void-returning receiver
// silently lowered the outer method against the discarded void
// result. `v.push(30).len()` returned 0 (void coerced as Vec
// header → vec_len reads garbage). Sister to v0.4.132/.136/.137
// (binop / let-RHS / cmp void). Fix routes void-mutator vec
// methods (push/pop/set/swap/extend/remove/insert/shuffle/free)
// to return "void" from kind-8 type_expr — previously they
// returned "" so the existing void checks didn't fire on
// `let x = v.push(N);` or chained calls. Halts now with TYP-023
// at the chain site, and TYP-021 at the bare-let site.

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    v.push(10);
    let r = v.push(20).len();
    print_int(r);
    0
}
