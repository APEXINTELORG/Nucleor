// v0.8.80 NUM-G2 Phase 1 — positive lock for math_abs.
// Confirms math_abs still computes correctly for in-range
// inputs after the i64::MIN guard added in v0.8.80.
//
// Expected: rc=0 (six assertions pass).

import "stdlib/rods/math.nr"

fn main() -> i64 {
    let mut fails: i64 = 0;
    if math_abs(0) != 0 { fails = fails + 1; };
    if math_abs(1) != 1 { fails = fails + 1; };
    if math_abs(-1) != 1 { fails = fails + 1; };
    if math_abs(42) != 42 { fails = fails + 1; };
    if math_abs(-42) != 42 { fails = fails + 1; };
    if math_abs(9223372036854775807) != 9223372036854775807 { fails = fails + 1; };  // i64::MAX
    return fails;
}
