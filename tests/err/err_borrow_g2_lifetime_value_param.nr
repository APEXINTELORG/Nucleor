// EXPECT: BORROW-G2-LIFETIME returned reference is derived from parameter
// RFC-0062 G-2 Phase 2b/3/4 — single-input lifetime check (negative
// fixture). The fn has exactly one ref-typed parameter (`x`), but
// the returned reference is `&y`, where `y` is a value-typed
// parameter. The returned region traces back to a different
// parameter than the single ref input, so the check fires
// BORROW-G2-LIFETIME at error severity.
fn borrow_other_param(x: &i32, y: i32) -> &i32 {
    &y
}

fn main() -> i32 {
    let v: i32 = 7;
    let r: &i32 = borrow_other_param(&v, 9);
    print_int(*r);
    0
}
