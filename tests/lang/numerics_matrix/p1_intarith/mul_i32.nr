// p1_intarith/mul_i32.nr — Phase 1: native i32 *
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i32 = 1000;
    let b: i32 = 1000;
    let c: i32 = a * b;
    if c != 1000000 {
        print("FAIL: 1000 * 1000\n");
        return 1;
    };
    print("OK mul_i32\n");
    return 0;
}
