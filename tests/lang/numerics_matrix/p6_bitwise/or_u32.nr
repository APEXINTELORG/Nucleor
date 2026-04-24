// p6_bitwise/or_u32.nr — Phase 6: u32 `|` width-correct
fn main() -> i32 {
    let a: u32 = 0xF0;
    let b: u32 = 0x0F;
    let c: u32 = a | b;
    let want: u32 = 255;
    if c != want {
        print("FAIL: u32 0xF0 | 0x0F\n");
        return 1;
    };
    print("OK or_u32\n");
    return 0;
}
