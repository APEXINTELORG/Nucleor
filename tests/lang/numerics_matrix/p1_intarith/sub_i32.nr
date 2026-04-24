// p1_intarith/sub_i32.nr — Phase 1: native i32 -
// Expected to FAIL until v0.2.308 lands width-aware emit_arith.

fn main() -> i32 {
    let a: i32 = 1000;
    let b: i32 = 200;
    let c: i32 = a - b;
    if c != 800 {
        print("FAIL: 1000 - 200\n");
        return 1;
    };
    print("OK sub_i32\n");
    return 0;
}
