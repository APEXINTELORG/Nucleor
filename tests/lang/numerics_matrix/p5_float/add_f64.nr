// p5_float/add_f64.nr — Phase 5: native f64 `+`
fn main() -> i32 {
    let a: f64 = 1.5;
    let b: f64 = 2.5;
    let c: f64 = a + b;
    let want: f64 = 4.0;
    if c != want {
        print("FAIL: f64 1.5 + 2.5\n");
        return 1;
    };
    print("OK add_f64\n");
    return 0;
}
