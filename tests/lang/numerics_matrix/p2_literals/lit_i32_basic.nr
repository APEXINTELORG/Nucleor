// p2_literals/lit_i32_basic.nr — Phase 2: i32 suffix literal
fn main() -> i32 {
    let a: i32 = 1234567i32;
    if a != 1234567 {
        print("FAIL: 1234567i32 != 1234567\n");
        return 1;
    };
    print("OK lit_i32_basic\n");
    return 0;
}
