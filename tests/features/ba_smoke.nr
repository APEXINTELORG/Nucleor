// v0.8.242 stdlib/rods/ba.nr first test coverage.
//
// Bundle adjustment (visual SLAM back-end). Pre-v0.8.242: zero
// coverage on the standalone rod. set_cam / set_pt / get_cam /
// get_pt all use raw double[] pointers; deferred to dedicated
// visual-SLAM ships.
//
// Locks four lifecycle invariants:
//
//   1. **ba_new returns valid handle** — non-zero.
//   2. **Empty cost is zero** — no observations → no
//      reprojection error.
//   3. **Multiple distinct BA problems** — two constructions →
//      distinct handles.
//   4. **ba_free does not crash** on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/ba.nr"

fn check_new_valid() -> i64 {
    let h: i64 = ba_new(2, 3,
        f64_to_bits(500.0), f64_to_bits(320.0), f64_to_bits(240.0));
    if h == 0 { return 1; };
    ba_free(h);
    return 0;
}

fn check_empty_cost_zero() -> i64 {
    let h: i64 = ba_new(2, 3,
        f64_to_bits(500.0), f64_to_bits(320.0), f64_to_bits(240.0));
    let c: f64 = f64_from_bits(ba_total_cost(h));
    ba_free(h);
    if c != 0.0 { return 2; };
    return 0;
}

fn check_distinct_handles() -> i64 {
    let a: i64 = ba_new(2, 2,
        f64_to_bits(500.0), f64_to_bits(320.0), f64_to_bits(240.0));
    let b: i64 = ba_new(2, 2,
        f64_to_bits(500.0), f64_to_bits(320.0), f64_to_bits(240.0));
    let same: i64 = if a == b { 1 } else { 0 };
    ba_free(a);
    ba_free(b);
    if same == 1 { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = ba_new(1, 1,
        f64_to_bits(100.0), f64_to_bits(50.0), f64_to_bits(50.0));
    ba_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_empty_cost_zero();
    fails = fails + check_distinct_handles();
    fails = fails + check_free_non_crashing();
    return fails;
}
