// p1_intarith/add_i32.nr — Phase 1: native i32 +
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i32 = 1000000;
    let b: i32 = 234567;
    let c: i32 = a + b;
    if c != 1234567 {
        print("FAIL: 1000000 + 234567\n");
        return 1;
    };
    print("OK add_i32\n");
    return 0;
}
