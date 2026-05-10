// F-NUM-003 negative proof: bit positions must be in 0..=63.
import "stdlib/rods/bitwise.nr"

fn main() -> i64 {
    return bit_test(1, 0 - 1);
}
