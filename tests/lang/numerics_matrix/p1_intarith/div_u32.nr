// p1_intarith/div_u32.nr — Phase 1: native u32 /
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: u32 = 1000;
    let b: u32 = 7;
    let c: u32 = a / b;
    if c != 142 {
        print("FAIL: 1000 / 7 = 142\n");
        return 1;
    };
    print("OK div_u32\n");
    return 0;
}
