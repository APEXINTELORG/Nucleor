// p1_intarith/mul_u8.nr — Phase 1: native u8 *
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: u8 = 10;
    let b: u8 = 20;
    let c: u8 = a * b;
    if c != 200 {
        print("FAIL: 10 * 20 = 200\n");
        return 1;
    };
    print("OK mul_u8\n");
    return 0;
}
