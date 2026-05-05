// v0.8.80 NUM-G2 Phase 1 — negative lock for math_abs(i64::MIN).
// EXPECT: runtime panic math_abs(i64::MIN)
// EXPECT-RUNTIME: math_abs(i64::MIN) is undefined behavior
//
// Pre-fix: rc=0 with silent miscompute (returned IMIN itself,
// negative, violating the implicit non-negative contract).
// Post-fix: panic — same loud failure as strict mode.
//
// Sister to err_numg2_math_gcd_imin.nr (the cascade case).

import "stdlib/rods/math.nr"

fn main() -> i64 {
    let imin: i64 = -9223372036854775807 - 1;
    let r: i64 = math_abs(imin);  // panics
    return r;
}
