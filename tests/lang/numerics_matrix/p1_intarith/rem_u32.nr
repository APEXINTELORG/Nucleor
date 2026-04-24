// p1_intarith/rem_u32.nr — Phase 1: native u32 %
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: u32 = 1000;
    let b: u32 = 7;
    let c: u32 = a % b;
    if c != 6 {
        print("FAIL: 1000 % 7 = 6\n");
        return 1;
    };
    print("OK rem_u32\n");
    return 0;
}
