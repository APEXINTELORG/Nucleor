// v0.8.81 NUM-G2 Phase 1 — math_pow_int overflow lock.
// EXPECT: runtime panic integer overflow
// EXPECT-RUNTIME: math_pow_int overflow: result exceeds i64 range
//
// Pre-fix: math_pow_int(2, 63) silently wrapped to i64::MIN
// under NUCLEOR_INT_STRICT_INTRIN=0. Post-fix: reverse-divide
// guard catches overflow at the multiply that would push past
// i64::MAX (2^62 -> 2^63 wraps).

import "stdlib/rods/math.nr"

fn main() -> i64 {
    let r: i64 = math_pow_int(2, 63);  // overflows
    return r;
}
