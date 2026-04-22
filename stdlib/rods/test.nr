// =====================================================
// rods/test — Test framework with assertions
// =====================================================
// Import: import "stdlib/rods/test.nr"
// Depends: import "stdlib/rods/fmt.nr" (for fmt_int)
// Provides: test_new, test_assert, test_assert_eq, test_assert_neq,
//   test_assert_str_eq, test_assert_true, test_assert_false,
//   test_pass, test_fail, test_summary
// =====================================================

import "stdlib/rods/fmt.nr"

// Test context layout (Vec):
//   [0] = total tests run
//   [1] = tests passed
//   [2] = tests failed
//   [3] = failure messages Vec<str>

fn test_new() -> Vec<i32> {
    let mut ctx: Vec<i32> = Vec::new();
    ctx.push(0);
    ctx.push(0);
    ctx.push(0);
    let mut msgs: Vec<i32> = Vec::new();
    ctx.push(msgs);
    return ctx;
}

fn test_pass(ctx: Vec<i32>, name: str) {
    vec_set(ctx, 0, ctx.get(0) + 1);
    vec_set(ctx, 1, ctx.get(1) + 1);
    print(str_concat("  PASS: ", name));
}

fn test_fail(ctx: Vec<i32>, name: str, msg: str) {
    vec_set(ctx, 0, ctx.get(0) + 1);
    vec_set(ctx, 2, ctx.get(2) + 1);
    let fail_msg: str = str_concat("  FAIL: ", str_concat(name, str_concat(" — ", msg)));
    print(fail_msg);
    let msgs: i64 = ctx.get(3);
    vec_push(msgs, fail_msg);
}

fn test_assert(ctx: Vec<i32>, name: str, cond: i64) {
    if cond != 0 { test_pass(ctx, name); }
    else { test_fail(ctx, name, "assertion failed"); };
}

fn test_assert_true(ctx: Vec<i32>, name: str, cond: i64) {
    if cond != 0 { test_pass(ctx, name); }
    else { test_fail(ctx, name, "expected true, got false"); };
}

fn test_assert_false(ctx: Vec<i32>, name: str, cond: i64) {
    if cond == 0 { test_pass(ctx, name); }
    else { test_fail(ctx, name, "expected false, got true"); };
}

fn test_assert_eq(ctx: Vec<i32>, name: str, got: i64, expected: i64) {
    if got == expected { test_pass(ctx, name); }
    else {
        let mut sb: i64 = sb_new();
        sb_append(sb, "expected ");
        sb_append(sb, fmt_int(expected));
        sb_append(sb, ", got ");
        sb_append(sb, fmt_int(got));
        test_fail(ctx, name, sb_to_str(sb));
    };
}

fn test_assert_neq(ctx: Vec<i32>, name: str, got: i64, not_expected: i64) {
    if got != not_expected { test_pass(ctx, name); }
    else {
        let mut sb: i64 = sb_new();
        sb_append(sb, "expected not ");
        sb_append(sb, fmt_int(not_expected));
        sb_append(sb, ", but got it");
        test_fail(ctx, name, sb_to_str(sb));
    };
}

fn test_assert_str_eq(ctx: Vec<i32>, name: str, got: str, expected: str) {
    if str_eq(got, expected) { test_pass(ctx, name); }
    else {
        let mut sb: i64 = sb_new();
        sb_append(sb, "expected \"");
        sb_append(sb, expected);
        sb_append(sb, "\", got \"");
        sb_append(sb, got);
        sb_append(sb, "\"");
        test_fail(ctx, name, sb_to_str(sb));
    };
}

fn test_summary(ctx: Vec<i32>) -> i64 {
    print("");
    let total: i64 = ctx.get(0);
    let passed: i64 = ctx.get(1);
    let failed: i64 = ctx.get(2);
    let mut sb: i64 = sb_new();
    sb_append(sb, "Results: ");
    sb_append(sb, fmt_int(passed));
    sb_append(sb, "/");
    sb_append(sb, fmt_int(total));
    sb_append(sb, " passed");
    if failed > 0 {
        sb_append(sb, ", ");
        sb_append(sb, fmt_int(failed));
        sb_append(sb, " FAILED");
    };
    print(sb_to_str(sb));
    if failed > 0 { return 1; };
    return 0;
}
