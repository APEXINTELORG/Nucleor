// p4_cast/cast_i32_neg_to_i8.nr — Phase 4: cast `neg i32 to i8 trunc`
fn main() -> i32 {
    let a: i32 = 0 - 200;
    let b: i8 = a as i8;
    let want: i8 = 56;
    if b != want {
        print("FAIL: neg i32 to i8 trunc\n");
        return 1;
    };
    print("OK cast_i32_neg_to_i8\n");
    return 0;
}
