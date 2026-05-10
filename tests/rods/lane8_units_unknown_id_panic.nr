// F-NUM-002 negative proof: unknown unit IDs cannot round-trip silently.
// EXPECT_RUNTIME_PANIC: UNIT-DIM-002
import "stdlib/rods/units.nr"

fn main() -> i64 {
    let bad: f64 = unit_convert_f64(42.0, 999, 1000);
    print(f64_to_str(f64_to_bits(bad)));
    return 0;
}
