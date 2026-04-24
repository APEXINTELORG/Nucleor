// p4_cast/cast_u8_to_i32.nr — Phase 4: cast `zero-ext u8 to i32`
fn main() -> i32 {
    let a: u8 = 200;
    let b: i32 = a as i32;
    let want: i32 = 200;
    if b != want {
        print("FAIL: zero-ext u8 to i32\n");
        return 1;
    };
    print("OK cast_u8_to_i32\n");
    return 0;
}
