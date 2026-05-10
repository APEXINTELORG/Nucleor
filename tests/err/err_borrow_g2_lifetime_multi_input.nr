// EXPECT: BORROW-G2-LIFETIME returned reference is derived from parameter
// G2-A-1: explicit multi-input lifetimes must reject returning a
// value whose source lifetime differs from the declared return lifetime.
fn pick_first_lifetime<'a, 'b>(x: &'a i32, y: &'b i32) -> &'a i32 {
    y
}

fn main() -> i32 {
    let a: i32 = 1;
    let b: i32 = 2;
    let r: &i32 = pick_first_lifetime(&a, &b);
    print_int(*r);
    0
}
