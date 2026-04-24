// p4_cast/cast_f32_to_i32.nr — Phase 4: cast `f32 to i32 trunc toward zero`
fn main() -> i32 {
    let a: f32 = 3.7;
    let b: i32 = a as i32;
    let want: i32 = 3;
    if b != want {
        print("FAIL: f32 to i32 trunc toward zero\n");
        return 1;
    };
    print("OK cast_f32_to_i32\n");
    return 0;
}
