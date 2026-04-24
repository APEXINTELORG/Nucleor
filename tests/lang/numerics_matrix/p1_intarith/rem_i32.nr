// p1_intarith/rem_i32.nr — Phase 1: native i32 %
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i32 = 100;
    let b: i32 = 3;
    let c: i32 = a % b;
    if c != 1 {
        print("FAIL: 100 % 3 = 1\n");
        return 1;
    };
    print("OK rem_i32\n");
    return 0;
}
