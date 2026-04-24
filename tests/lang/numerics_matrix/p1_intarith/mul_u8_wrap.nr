// p1_intarith/mul_u8_wrap.nr — Phase 1: u8 `*` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {
    let a: u8 = 100;
    let b: u8 = 100;
    let c: u8 = a * b;
    if c != (16) {
        print("FAIL: 100 * 100 = 10000, mod 256 = 16\n");
        return 1;
    };
    print("OK mul_u8_wrap\n");
    return 0;
}
