// p1_intarith/cmp_lt_u32.nr — Phase 1: u32 comparison `<`
fn main() -> i32 {
    let a: u32 = 100;
    let b: u32 = 200;
    if (a < b) != 1 {
        print("FAIL: 100 < 200\n");
        return 1;
    };
    print("OK cmp_lt_u32\n");
    return 0;
}
