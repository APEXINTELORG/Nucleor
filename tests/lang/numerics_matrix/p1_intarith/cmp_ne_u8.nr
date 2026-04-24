// p1_intarith/cmp_ne_u8.nr — Phase 1: u8 comparison `!=`
fn main() -> i32 {
    let a: u8 = 100;
    let b: u8 = 200;
    if (a != b) != 1 {
        print("FAIL: 100 != 200\n");
        return 1;
    };
    print("OK cmp_ne_u8\n");
    return 0;
}
