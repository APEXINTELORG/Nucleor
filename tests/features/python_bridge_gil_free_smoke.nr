// v0.8.273 R06-D2 Phase 1 — Python bridge result-free coverage.
//
// Per audit `BUILD_PLAN_R06_interop_ffi.md` §1 R06-D2 (HIGH):
// pre-v0.8.273 `rods_py_eval` and `rods_py_call_str` returned
// malloc'd heap copies of UTF-8 Python results with no exposed
// reclaim path. Adopters either leaked or guessed which free() to
// call.
//
// Phase 1 (this ship): adds `rods_py_free_str` reclaim hook with
// static-fallback rejection (the "<error>" / "" returns on the
// failure path are NOT heap-owned and must not be free()'d).
// Phase 2 wires GIL ensure/release brackets for thread-safe use
// (the existing rod is single-threaded today).
//
// Phase 1 acceptance criteria:
//   - Python string path has explicit ownership: ✅ free hook
//     exposed; static fallbacks rejected to prevent crash;
//   - calls are GIL-safe: ⚙️ Phase 2 (single-threaded today; not
//     a regression);
//   - unavailable runtime reports stable diagnostic: ✅
//     `py_available()` returns 0 on Windows boxes without Python.
//
// This fixture is GATED on `py_available() == 0` to avoid Python
// dependency in CI. The free-hook + py_available diagnostic itself
// are exercised regardless of Python availability.
//
// Locks 3 invariants:
//   1. `py_available()` returns 0 or 1 deterministically — never
//      crashes; returns a stable diagnostic.
//   2. `py_free_str("")` is no-op — empty static fallback safely
//      rejected (does not crash).
//   3. `py_free_str("<error>")` is no-op — error-fallback
//      static safely rejected.
//
// Expected: rc=0.

import "stdlib/rods/python.nr"

fn check_py_available_stable() -> i64 {
    let a: i64 = py_available();
    // py_available returns 0 (no Python) or 1 (loaded). Anything
    // else is a bug.
    if a != 0 && a != 1 { return 1; };
    return 0;
}

fn check_py_free_empty_safe() -> i64 {
    py_free_str("");
    return 0;
}

fn check_py_free_error_fallback_safe() -> i64 {
    // The "<error>" fallback string is a static literal in
    // python_rt.c — must NOT be free()'d. py_free_str must reject
    // it (no-op).
    py_free_str("<error>");
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_py_available_stable();
    fails = fails + check_py_free_empty_safe();
    fails = fails + check_py_free_error_fallback_safe();
    return fails;
}
