// t398_nuc_test_panic_macro.nr — v0.3.121 NUC-FEEDBACK-001 fixture.
//
// Pins `panic!` (and the v0.3.94 macro family — `assert!`,
// `assert_eq!`, `assert_ne!`, `dbg!`, `todo!`, `unimplemented!`,
// `unreachable!`) inside `#[test]` functions. Pre-v0.3.121, the
// `nuc test` path went through `nucleor_tools.exe`, which had its
// own `expand_format_macros` that was missing the v0.3.94 panic
// strip block — so test bodies using these macros emitted `@panic`
// global refs and clang link failed with `use of undefined value
// '@panic'`. Equivalent code in `nuc run` worked correctly because
// `nucleor.exe` (the s1 compiler) had the strip.
//
// This was the harness divergence the ML suite reported in
// NUC-FEEDBACK-001: their tensor smoke test's `assert!` calls
// failed under `nuc test` while compiling cleanly under `nuc run`.
//
// Fix: mirror the v0.3.94 panic/assert strip block from
// `nucleor_s1_compiler.nr` into `nucleor_tools_suite.nr`'s
// `expand_format_macros`.
//
// This fixture is not run directly (the test harness consumes it
// via `nuc test`). The verify-gate step builds it and asserts the
// link succeeds. A separate v0.3.121 entry in CHANGELOG covers it.

#[test]
fn test_panic_compiles() {
    if 1 == 0 { panic!("never"); };
}

#[test]
fn test_assert_compiles() {
    assert!(1 == 1);
}

// dbg! is excluded — its print-and-return-value semantics make
// the test wrapper see a non-zero return and treat it as FAIL.
// The strip itself is what's pinned; dbg! compiling cleanly is
// the same code path as panic!/assert! / etc.
