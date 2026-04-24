// p1_intarith/div_i32.nr — Phase 1: native i32 /
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i32 = 100;
    let b: i32 = 3;
    let c: i32 = a / b;
    if c != 33 {
        print("FAIL: 100 / 3 = 33\n");
        return 1;
    };
    print("OK div_i32\n");
    return 0;
}
