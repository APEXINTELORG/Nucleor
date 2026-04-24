// p1_intarith/add_i16.nr — Phase 1: native i16 +
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i16 = 30000;
    let b: i16 = 1000;
    let c: i16 = a + b;
    if c != 31000 {
        print("FAIL: 30000 + 1000 = 31000\n");
        return 1;
    };
    print("OK add_i16\n");
    return 0;
}
