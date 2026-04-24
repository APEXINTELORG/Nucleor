// p1_intarith/add_u8_wrap.nr — Phase 1: u8 `+` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {
    let a: u8 = 250;
    let b: u8 = 10;
    let c: u8 = a + b;
    if c != (4) {
        print("FAIL: 250 + 10 wraps to 4 (mod 256)\n");
        return 1;
    };
    print("OK add_u8_wrap\n");
    return 0;
}
