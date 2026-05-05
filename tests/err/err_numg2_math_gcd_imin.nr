// v0.8.80 NUM-G2 Phase 1 — math_gcd cascade lock.
// EXPECT: runtime panic math_abs(i64::MIN)
// EXPECT-RUNTIME: math_abs(i64::MIN) is undefined behavior
//
// math_gcd internally calls math_abs on both arguments. Pre-fix:
// math_gcd(i64::MIN, 7) returned -1 silently (negative GCD).
// Post-fix: cascades to the math_abs panic at the i64::MIN guard.

import "stdlib/rods/math.nr"

fn main() -> i64 {
    let imin: i64 = -9223372036854775807 - 1;
    let g: i64 = math_gcd(imin, 7);  // cascades to math_abs panic
    return g;
}
