// p5_float/mul_f32.nr — Phase 5: native f32 `*`
fn main() -> i32 {
    let a: f32 = 2.0;
    let b: f32 = 3.5;
    let c: f32 = a * b;
    let want: f32 = 7.0;
    if c != want {
        print("FAIL: f32 2.0 * 3.5\n");
        return 1;
    };
    print("OK mul_f32\n");
    return 0;
}
