// v0.8.186 stdlib/rods/test.nr first test coverage.
//
// Test framework rod with pass/fail counters, assert helpers,
// and summary printer. Pre-v0.8.186: zero coverage on the
// framework itself (it's used by other tests but never had
// a meta-test).
//
// Locks four invariants:
//   1. Fresh context: total=0, passed=0, failed=0.
//   2. assert_true increments pass count on truthy condition.
//   3. assert_false increments pass count on falsey condition.
//   4. assert_eq increments fail count on mismatch.
//
// We don't directly read counts via getters — the rod doesn't
// expose them — so we use vec_get on the underlying Vec layout
// (documented in the rod source: [0]=total, [1]=pass, [2]=fail).
//
// Expected: rc=0.

import "stdlib/rods/test.nr"

fn check_fresh_ctx() -> i64 {
    let ctx: Vec<i32> = test_new();
    if vec_get(ctx, 0) != 0 { return 1; };
    if vec_get(ctx, 1) != 0 { return 2; };
    if vec_get(ctx, 2) != 0 { return 4; };
    return 0;
}

fn check_assert_true_increments() -> i64 {
    let ctx: Vec<i32> = test_new();
    test_assert_true(ctx, "lock", 1);
    if vec_get(ctx, 0) != 1 { return 8; };
    if vec_get(ctx, 1) != 1 { return 16; };
    if vec_get(ctx, 2) != 0 { return 32; };
    return 0;
}

fn check_assert_false_increments() -> i64 {
    let ctx: Vec<i32> = test_new();
    test_assert_false(ctx, "lock", 0);
    if vec_get(ctx, 1) != 1 { return 64; };
    if vec_get(ctx, 2) != 0 { return 128; };
    return 0;
}

fn check_assert_eq_failure_increments_fail() -> i64 {
    let ctx: Vec<i32> = test_new();
    test_assert_eq(ctx, "lock", 5, 7); // 5 != 7 → fail
    if vec_get(ctx, 1) != 0 { return 256; };
    if vec_get(ctx, 2) != 1 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fresh_ctx();
    fails = fails + check_assert_true_increments();
    fails = fails + check_assert_false_increments();
    fails = fails + check_assert_eq_failure_increments_fail();
    return fails;
}
