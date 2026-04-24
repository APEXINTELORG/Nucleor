// p1_intarith/add_u32.nr — Phase 1: native u32 +
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: u32 = 1000000;
    let b: u32 = 1;
    let c: u32 = a + b;
    if c != 1000001 {
        print("FAIL: 1000000 + 1\n");
        return 1;
    };
    print("OK add_u32\n");
    return 0;
}
