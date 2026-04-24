// p4_cast/cast_i32_to_f32.nr — Phase 4: cast `i32 to f32`
fn main() -> i32 {
    let a: i32 = 100;
    let b: f32 = a as f32;
    let want: f32 = 100;
    if b != want {
        print("FAIL: i32 to f32\n");
        return 1;
    };
    print("OK cast_i32_to_f32\n");
    return 0;
}
