// F-NUM-003 negative proof: shift count 64 is outside the i64 range.
import "stdlib/rods/bitwise.nr"

fn main() -> i64 {
    return bit_shift_left(1, 64);
}
