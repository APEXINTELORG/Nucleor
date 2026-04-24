// p6_bitwise/and_u8.nr — Phase 6: u8 `&` width-correct
fn main() -> i32 {
    let a: u8 = 0xF0;
    let b: u8 = 0x0F;
    let c: u8 = a & b;
    let want: u8 = 0;
    if c != want {
        print("FAIL: u8 0xF0 & 0x0F\n");
        return 1;
    };
    print("OK and_u8\n");
    return 0;
}
