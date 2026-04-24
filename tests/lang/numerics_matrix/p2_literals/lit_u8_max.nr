// p2_literals/lit_u8_max.nr — Phase 2: u8 suffix literal
fn main() -> i32 {
    let a: u8 = 255u8;
    if a != 255 {
        print("FAIL: 255u8 != 255\n");
        return 1;
    };
    print("OK lit_u8_max\n");
    return 0;
}
