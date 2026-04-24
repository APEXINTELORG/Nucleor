// p4_cast/cast_f64_to_f32.nr — Phase 4: cast `f64 to f32 narrow`
fn main() -> i32 {
    let a: f64 = 3.14;
    let b: f32 = a as f32;
    let want: f32 = 3.14;
    if b != want {
        print("FAIL: f64 to f32 narrow\n");
        return 1;
    };
    print("OK cast_f64_to_f32\n");
    return 0;
}
