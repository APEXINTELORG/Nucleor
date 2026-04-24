// p2_literals/lit_negative_i8.nr — Phase 2: i8 suffix literal
fn main() -> i32 {
    let a: i8 = -100i8;
    if a != -100 {
        print("FAIL: -100i8 != -100\n");
        return 1;
    };
    print("OK lit_negative_i8\n");
    return 0;
}
