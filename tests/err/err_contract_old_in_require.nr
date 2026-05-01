// EXPECT: build fails with CONTRACT-010 mentioning fn name `f`.
// RFC-0006 — `old(...)` in `#[require]` must reject at compile time.
//
// v0.4.277 closes wrong-error finding filed by probe agent
// 2026-05-01: pre-fix, `#[require(old(x) > 0)]` emitted a
// misleading clang-link "undefined function `old()`" error.
// `old()` is only meaningful in `#[ensure]` (postconditions
// reference fn-entry state); `#[require]` runs BEFORE the body,
// so there's no prior state to snapshot. CONTRACT-010 names
// the semantic mismatch and the workaround.
//
// EXPECT: build fails with CONTRACT-010 mentioning fn name `f`.

#[require(old(x) > 0)]
fn f(x: i64) -> i64 { x }

fn main() -> i32 {
    print_int(f(5) as i32);
    0
}
