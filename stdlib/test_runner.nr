// Nucleor stdlib: test_runner
// Test execution infrastructure for bootstrap compiler.
// Models the @test attribute runner.

const TEST_PASS: i32 = 0;
const TEST_FAIL: i32 = 1;
const TEST_SKIP: i32 = 2;
const TEST_ERROR: i32 = 3;

struct TestResult {
    status: i32,
    assertion_count: i32,
}

fn test_pass(assertions: i32) -> TestResult {
    TestResult { status: TEST_PASS, assertion_count: assertions }
}

fn test_fail(assertions: i32) -> TestResult {
    TestResult { status: TEST_FAIL, assertion_count: assertions }
}

fn is_pass(r: TestResult) -> bool {
    r.status == TEST_PASS
}

fn status_label(s: i32) -> str {
    if s == TEST_PASS { "PASS" }
    else if s == TEST_FAIL { "FAIL" }
    else if s == TEST_SKIP { "SKIP" }
    else { "ERROR" }
}

// Test suite summary
struct TestSummary {
    total: i32,
    passed: i32,
    failed: i32,
    skipped: i32,
}

fn empty_summary() -> TestSummary {
    TestSummary { total: 0, passed: 0, failed: 0, skipped: 0 }
}

fn add_pass(total: i32, passed: i32) -> TestSummary {
    TestSummary { total: total + 1, passed: passed + 1, failed: 0, skipped: 0 }
}

fn add_fail(total: i32, failed: i32) -> TestSummary {
    TestSummary { total: total + 1, passed: 0, failed: failed + 1, skipped: 0 }
}

fn suite_is_green(s: TestSummary) -> bool {
    s.failed == 0
}

fn main() -> i32 {
    let r1: TestResult = test_pass(5);
    let r2: TestResult = test_fail(3);

    print(status_label(r1.status));
    print(status_label(r2.status));
    print_bool(is_pass(r1));
    print_bool(is_pass(r2));

    let s: TestSummary = empty_summary();
    print_bool(suite_is_green(s));

    let s2: TestSummary = add_pass(0, 0);
    print_int(s2.total);
    print_int(s2.passed);
    print_bool(suite_is_green(s2));
    0
}
