// bitwise.nr — bitwise rod
import "stdlib/rods/bitwise.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    if bit_and(255, 15) != 15 { print("FAIL bitwise: and"); fail = fail + 1; };
    if bit_or(240, 15) != 255 { print("FAIL bitwise: or"); fail = fail + 1; };
    if bit_xor(255, 15) != 240 { print("FAIL bitwise: xor"); fail = fail + 1; };
    if bit_shift_left(1, 8) != 256 { print("FAIL bitwise: shl"); fail = fail + 1; };
    if bit_shift_right(256, 8) != 1 { print("FAIL bitwise: shr"); fail = fail + 1; };
    if bit_test(255, 3) != 1 { print("FAIL bitwise: test"); fail = fail + 1; };
    if bit_set(0, 4) != 16 { print("FAIL bitwise: set"); fail = fail + 1; };
    if bit_clear(255, 0) != 254 { print("FAIL bitwise: clear"); fail = fail + 1; };
    if fail == 0 { print("OK bitwise"); return 0; };
    return 1;
}
