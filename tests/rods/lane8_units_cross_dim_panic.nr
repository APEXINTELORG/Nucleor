// F-NUM-002 negative proof: pressure cannot be converted to length.
import "stdlib/rods/units.nr"

fn main() -> i64 {
    let bad: f64 = unit_convert_f64(100.0, unit_Pa(), unit_m());
    print(f64_to_str(f64_to_bits(bad)));
    return 0;
}
