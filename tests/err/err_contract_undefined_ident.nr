// RFC-0006 — undefined identifier in `#[require]` predicate must
// reject at compile time (CONTRACT-011).
//
// v0.4.283 closes wrong-error finding filed by probe agent
// 2026-05-01: pre-fix, `#[require(undefined_var > 0)]` surfaced
// a misleading clang-link "undefined function `undefined_var()`"
// error — wrong identifier kind (it was used as a value, not a
// fn) and wrong phase (link instead of parse). CONTRACT-011 now
// halts at compile time naming the actual unbound ident.
//
// EXPECT: build fails with CONTRACT-011 mentioning fn name `f`
// and the bare ident `undefined_var`.

#[require(undefined_var > 0)]
fn f(x: i64) -> i64 { x }

fn main() -> i32 {
    print_int(f(5) as i32);
    0
}
