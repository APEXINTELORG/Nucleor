// t460_unresolved_field_pre_ir_halt.nr -- v0.3.198 regression fixture.
//
// NUC-FEEDBACK-010 follow-on: TRUE pre-IR halt for unresolved field
// access. Pre-v0.3.198 the lower_expr field-access path printed an
// actionable diagnostic (v0.3.193) but still emitted `%r.-1` to the
// IR, which then surfaced downstream as a confusing
// `clang: use of undefined value '%r.-1'` link error mixed with the
// already-printed diagnostic. The architectural blocker on a clean
// halt was that lower_expr returns a `(reg, block)` pair to ~44 call
// sites with no error channel.
//
// Fix (v0.3.198): sidestep the plumbing by calling `panic()` from the
// compiler itself. The s1 compiler IS a Nucleor program, so a panic()
// call invokes __nucleor_panic in the COMPILER's runtime, exiting the
// compiler process with status 1 BEFORE clang is ever invoked.
// Adopters now see the diagnostic followed by `PANIC: nucleor: cannot
// resolve field access .NAME` on stderr, no clang spew, no `%r.-1`.
//
// This fixture is positive — a successful struct field access with
// careful naming around contextual keywords. The negative test
// (deliberately unresolved field) is exercised in
// `tests/fixtures/probe_unresolved_field.nr` and verified manually
// (it must exit 1 with PANIC line).

struct Stat {
    static_count: i64,
    loop_count: i64,
    as_count: i64,
}

fn main() -> i64 {
    let s: Stat = Stat { static_count: 7, loop_count: 3, as_count: 11 };
    println!("{}", s.static_count);
    println!("{}", s.loop_count);
    println!("{}", s.as_count);
    return 0;
}
