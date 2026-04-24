// p6_bitwise/shl_u8.nr — Phase 6: u8 left shift via bit_shift_left rod.
import "stdlib/rods/bitwise.nr"

fn main() -> i32 {
    let a: u8 = 1;
    let b: i64 = 3;
    let c: u8 = bit_shift_left(a, b);
    let want: u8 = 8;
    if c != want {
        print("FAIL: u8 1 << 3\n");
        return 1;
    };
    print("OK shl_u8\n");
    return 0;
}
