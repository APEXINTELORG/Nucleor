// p2_literals/lit_u8_basic.nr — Phase 2: u8 suffix literal
fn main() -> i32 {
    let a: u8 = 200u8;
    if a != 200 {
        print("FAIL: 200u8 != 200\n");
        return 1;
    };
    print("OK lit_u8_basic\n");
    return 0;
}
