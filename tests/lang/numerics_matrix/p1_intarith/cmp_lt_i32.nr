// p1_intarith/cmp_lt_i32.nr — Phase 1: i32 comparison `<`
fn main() -> i32 {
    let a: i32 = -10;
    let b: i32 = 5;
    if (a < b) != 1 {
        print("FAIL: -10 < 5\n");
        return 1;
    };
    print("OK cmp_lt_i32\n");
    return 0;
}
