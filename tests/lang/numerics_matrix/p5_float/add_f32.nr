// p5_float/add_f32.nr — Phase 5: native f32 `+`
fn main() -> i32 {
    let a: f32 = 1.5;
    let b: f32 = 2.5;
    let c: f32 = a + b;
    let want: f32 = 4.0;
    if c != want {
        print("FAIL: f32 1.5 + 2.5\n");
        return 1;
    };
    print("OK add_f32\n");
    return 0;
}
