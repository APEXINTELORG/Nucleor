// p1_intarith/mul_i8_wrap.nr — Phase 1: i8 `*` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {
    let a: i8 = 50;
    let b: i8 = 3;
    let c: i8 = a * b;
    if c != (-106) {
        print("FAIL: 50 * 3 = 150 wraps to -106 in i8\n");
        return 1;
    };
    print("OK mul_i8_wrap\n");
    return 0;
}
