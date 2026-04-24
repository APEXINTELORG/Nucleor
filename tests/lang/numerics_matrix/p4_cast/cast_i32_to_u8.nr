// p4_cast/cast_i32_to_u8.nr — Phase 4: cast `trunc 300 to u8`
fn main() -> i32 {
    let a: i32 = 300;
    let b: u8 = a as u8;
    let want: u8 = 44;
    if b != want {
        print("FAIL: trunc 300 to u8\n");
        return 1;
    };
    print("OK cast_i32_to_u8\n");
    return 0;
}
