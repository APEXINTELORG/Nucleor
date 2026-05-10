// EXPECT: BORROW-G2-LIFETIME returned reference is derived from parameter
// G2-FN-1: the returned reference reaches the wrong parameter through
// an intermediate let-binding, so the lifetime root must still be
// followed and rejected.
fn borrow_other_param_via_let(x: &i32, y: i32) -> &i32 {
    let r: &i32 = &y;
    r
}

fn main() -> i32 {
    let v: i32 = 7;
    let r: &i32 = borrow_other_param_via_let(&v, 9);
    print_int(*r);
    0
}
