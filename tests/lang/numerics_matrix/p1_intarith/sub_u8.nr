// p1_intarith/sub_u8.nr — Phase 1: native u8 -
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: u8 = 200;
    let b: u8 = 50;
    let c: u8 = a - b;
    if c != 150 {
        print("FAIL: 200 - 50\n");
        return 1;
    };
    print("OK sub_u8\n");
    return 0;
}
