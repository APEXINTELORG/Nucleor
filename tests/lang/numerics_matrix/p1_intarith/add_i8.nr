// p1_intarith/add_i8.nr — Phase 1: native i8 +
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i8 = 100;
    let b: i8 = 20;
    let c: i8 = a + b;
    if c != 120 {
        print("FAIL: 100 + 20 = 120\n");
        return 1;
    };
    print("OK add_i8\n");
    return 0;
}
