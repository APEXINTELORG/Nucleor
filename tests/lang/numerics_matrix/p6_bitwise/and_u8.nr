// p6_bitwise/and_u8.nr — Phase 6: u8 bitwise AND via bit_and rod.
// Result narrows to u8 via the let-binding hook (Phase 1+).
import "stdlib/rods/bitwise.nr"

fn main() -> i32 {
    let a: u8 = 0xF0;
    let b: u8 = 0x0F;
    let c: u8 = bit_and(a, b);
    let want: u8 = 0;
    if c != want {
        print("FAIL: u8 0xF0 & 0x0F\n");
        return 1;
    };
    print("OK and_u8\n");
    return 0;
}
