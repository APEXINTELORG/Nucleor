// p5_float/div_f32.nr — Phase 5: native f32 `/`
fn main() -> i32 {
    let a: f32 = 10.0;
    let b: f32 = 4.0;
    let c: f32 = a / b;
    let want: f32 = 2.5;
    if c != want {
        print("FAIL: f32 10.0 / 4.0\n");
        return 1;
    };
    print("OK div_f32\n");
    return 0;
}
