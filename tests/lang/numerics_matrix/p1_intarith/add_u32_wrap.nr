// p1_intarith/add_u32_wrap.nr — Phase 1: u32 `+` width-boundary
// Currently fails (i64 storage). Phase 1 fixes by emitting
// narrow-width LLVM ops that wrap at the type's bit boundary.

fn main() -> i32 {
    let a: u32 = 4000000000;
    let b: u32 = 500000000;
    let c: u32 = a + b;
    if c != (205032704) {
        print("FAIL: 4e9 + 5e8 wraps mod 2^32\n");
        return 1;
    };
    print("OK add_u32_wrap\n");
    return 0;
}
