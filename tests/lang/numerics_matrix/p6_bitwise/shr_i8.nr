// p6_bitwise/shr_i8.nr — Phase 6: i8 arithmetic right shift via
// bit_shift_right_signed rod (sign-preserving).
import "stdlib/rods/bitwise.nr"

fn main() -> i32 {
    let a: i8 = 0 - 8;
    let b: i64 = 1;
    let c: i8 = bit_shift_right_signed(a, b);
    let want: i8 = 0 - 4;
    if c != want {
        print("FAIL: i8 -8 >> 1 (arithmetic)\n");
        return 1;
    };
    print("OK shr_i8\n");
    return 0;
}
