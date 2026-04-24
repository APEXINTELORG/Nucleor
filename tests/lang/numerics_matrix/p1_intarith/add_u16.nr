// p1_intarith/add_u16.nr — Phase 1: native u16 +
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: u16 = 60000;
    let b: u16 = 1000;
    let c: u16 = a + b;
    if c != 61000 {
        print("FAIL: 60000 + 1000\n");
        return 1;
    };
    print("OK add_u16\n");
    return 0;
}
