// RFC-0006 Design by Contract — `#[no_check]` per-fn opt-out.
//
// v0.4.258: marker attribute that suppresses `#[require(...)]`
// and `#[ensure(...)]` runtime checks for a single fn. The
// predicates remain visible in source as documentation, but no
// LLVM call to `__nucleor_contract_require` /
// `__nucleor_contract_ensure` is emitted. Useful for hot-path
// fns where the adopter has profiled the contract overhead and
// wants to opt out for one fn without flipping the whole build
// to `NUCLEOR_DBC_MODE=release`.
//
// Semantics:
// - `#[no_check]` is a marker attr — no expression argument.
// - When present, ALL `#[require(...)]` and `#[ensure(...)]`
//   attached to the same fn are skipped at codegen.
// - Adopter-visible: the predicates still appear in source, the
//   compiler still parses them (catching syntax errors), but no
//   runtime cost is paid.
// - This fixture exercises the violation path: a `#[require]`
//   that WOULD trip is bypassed by the marker. Runtime returns
//   normally, no CONTRACT-001 panic.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_no_check".

#[no_check]
#[require(x > 0)]
fn hot_path_skipped(x: i64) -> i64 {
    x * 2
}

#[no_check]
#[ensure(result >= 100)]
fn hot_path_skipped_ensure(x: i64) -> i64 {
    x
}

#[require(x > 0)]
fn checked_path(x: i64) -> i64 {
    x * 2
}

fn main() -> i64 {
    // Negative input would normally trip CONTRACT-001 on a
    // checked fn. With #[no_check] the require is bypassed.
    let a: i64 = hot_path_skipped(-5);
    if a != -10 { print("FAIL hot_path_skipped"); return 1; };

    // Result-below-100 would normally trip CONTRACT-002. With
    // #[no_check] the ensure is bypassed.
    let b: i64 = hot_path_skipped_ensure(7);
    if b != 7 { print("FAIL hot_path_skipped_ensure"); return 1; };

    // Sanity: a non-no_check fn with the same require still
    // works on the passing path.
    let c: i64 = checked_path(3);
    if c != 6 { print("FAIL checked_path"); return 1; };

    print("OK rfc0006_no_check");
    0
}
