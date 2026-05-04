// v0.8.81 NUM-G2 Phase 1 — math_pow_int positive lock.
// Confirms math_pow_int still computes correctly for safe
// inputs after the overflow guard added in v0.8.81.
//
// Expected: rc=0 (eight assertions pass).

import "stdlib/rods/math.nr"

fn main() -> i64 {
    let mut fails: i64 = 0;
    if math_pow_int(2, 0) != 1 { fails = fails + 1; };
    if math_pow_int(2, 1) != 2 { fails = fails + 1; };
    if math_pow_int(2, 10) != 1024 { fails = fails + 1; };
    if math_pow_int(2, 62) != 4611686018427387904 { fails = fails + 1; };  // safe: 2^62
    if math_pow_int(0, 5) != 0 { fails = fails + 1; };
    if math_pow_int(1, 1000) != 1 { fails = fails + 1; };
    if math_pow_int(-1, 100) != 1 { fails = fails + 1; };  // even exp
    if math_pow_int(-1, 101) != -1 { fails = fails + 1; }; // odd exp
    return fails;
}
