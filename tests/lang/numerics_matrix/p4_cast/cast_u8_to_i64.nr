// p4_cast/cast_u8_to_i64.nr — Phase 4: cast `zero-ext u8 to i64`
fn main() -> i32 {
    let a: u8 = 255;
    let b: i64 = a as i64;
    let want: i64 = 255;
    if b != want {
        print("FAIL: zero-ext u8 to i64\n");
        return 1;
    };
    print("OK cast_u8_to_i64\n");
    return 0;
}
