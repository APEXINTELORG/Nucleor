// p1_intarith/cmp_eq_i32.nr — Phase 1: i32 comparison `==`
fn main() -> i32 {
    let a: i32 = 42;
    let b: i32 = 42;
    if (a == b) != 1 {
        print("FAIL: 42 == 42\n");
        return 1;
    };
    print("OK cmp_eq_i32\n");
    return 0;
}
