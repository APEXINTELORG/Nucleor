// p1_intarith/mul_i32_wrap.nr — Phase 1: i32 `*` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {
    let a: i32 = 100000;
    let b: i32 = 100000;
    let c: i32 = a * b;
    if c != (1410065408) {
        print("FAIL: 1e10 wraps to 1410065408 in i32\n");
        return 1;
    };
    print("OK mul_i32_wrap\n");
    return 0;
}
