// p6_bitwise/shr_i8.nr — Phase 6: i8 `>>` width-correct
fn main() -> i32 {
    let a: i8 = 0 - 8;
    let b: i8 = 1;
    let c: i8 = a >> b;
    let want: i8 = 0 - 4;
    if c != want {
        print("FAIL: i8 0 - 8 >> 1\n");
        return 1;
    };
    print("OK shr_i8\n");
    return 0;
}
