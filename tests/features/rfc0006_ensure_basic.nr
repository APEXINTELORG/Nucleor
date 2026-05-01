// RFC-0006 Design by Contract — `#[ensure(EXPR)]` runtime check.
//
// v0.4.246 substrate: source-text scanner extracts `#[ensure(EXPR)]`
// attributes; lower_fn binds `result` in sym to a fresh alloca
// holding the return value at fn-tail-return sites, lowers the
// predicate, and emits `__nucleor_contract_ensure(result_of_predicate)`.
// On a 0 result the runtime helper prints `CONTRACT-002: ensure
// postcondition violated` and exits 1.
//
// This fixture exercises the PASSING path: every fn returns a
// value satisfying its postcondition. The negative path is
// covered by the inline-generated violation in
// `tools/verify.sh`'s t_rfc0006_ensure_runtime step.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_ensure_basic".

#[ensure(result >= 0)]
fn abs(x: i64) -> i64 {
    if x < 0 { 0 - x } else { x }
}

#[ensure(result > 0)]
fn always_positive(x: i64) -> i64 {
    if x > 0 { x } else { 1 }
}

fn main() -> i64 {
    let a: i64 = abs(0 - 7);
    if a != 7 { print("FAIL abs negative"); return 1; };

    let b: i64 = abs(42);
    if b != 42 { print("FAIL abs positive"); return 1; };

    let c: i64 = always_positive(0 - 100);
    if c != 1 { print("FAIL always_positive negative"); return 1; };

    let d: i64 = always_positive(50);
    if d != 50 { print("FAIL always_positive positive"); return 1; };

    print("OK rfc0006_ensure_basic");
    0
}
