// p2_literals/lit_underscore.nr — Phase 2: i32 suffix literal
fn main() -> i32 {
    let a: i32 = 1_000_000i32;
    if a != 1000000 {
        print("FAIL: 1_000_000i32 != 1000000\n");
        return 1;
    };
    print("OK lit_underscore\n");
    return 0;
}
