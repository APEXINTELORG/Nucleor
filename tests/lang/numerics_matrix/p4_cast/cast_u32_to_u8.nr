// p4_cast/cast_u32_to_u8.nr — Phase 4: cast `trunc u32 1000 to u8`
fn main() -> i32 {
    let a: u32 = 1000;
    let b: u8 = a as u8;
    let want: u8 = 232;
    if b != want {
        print("FAIL: trunc u32 1000 to u8\n");
        return 1;
    };
    print("OK cast_u32_to_u8\n");
    return 0;
}
