// RFC-0006 Design by Contract — `#[require(EXPR)]` runtime check.
//
// v0.4.245 substrate: source-text scanner extracts `#[require(EXPR)]`
// attributes from fn declarations, lexes + parses the expression
// into the AST pool, and the lower_fn pre-processor emits a
// `__nucleor_contract_require(result)` call at fn entry. On a 0
// result the runtime helper prints `CONTRACT-001: require
// precondition violated` and exits 1.
//
// This fixture exercises the PASSING path: every call site
// satisfies the precondition. The negative path lives in
// `tests/err/err_contract_require_violated.nr`.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_require_basic".

#[require(x > 0)]
fn double_pos(x: i64) -> i64 {
    x * 2
}

#[require(n >= 0)]
fn factorial_nonneg(n: i64) -> i64 {
    let mut result: i64 = 1;
    let mut i: i64 = 1;
    while i <= n {
        result = result * i;
        i = i + 1;
    };
    result
}

fn main() -> i64 {
    let a: i64 = double_pos(5);
    if a != 10 { print("FAIL double_pos"); return 1; };

    let b: i64 = factorial_nonneg(5);
    if b != 120 { print("FAIL factorial_nonneg"); return 1; };

    let c: i64 = factorial_nonneg(0);
    if c != 1 { print("FAIL factorial_nonneg(0)"); return 1; };

    print("OK rfc0006_require_basic");
    0
}
