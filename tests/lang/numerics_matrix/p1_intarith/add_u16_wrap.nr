// p1_intarith/add_u16_wrap.nr — Phase 1: u16 `+` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {
    let a: u16 = 65000;
    let b: u16 = 1000;
    let c: u16 = a + b;
    if c != (464) {
        print("FAIL: 65000 + 1000 wraps mod 65536\n");
        return 1;
    };
    print("OK add_u16_wrap\n");
    return 0;
}
