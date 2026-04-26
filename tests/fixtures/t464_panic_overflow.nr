// t464_panic_overflow.nr -- v0.3.207 ergonomic strict-arithmetic surface.
//
// Pre-v0.3.207 the runtime had `checked_*_i64` (returns 0 + sets a
// flag the caller had to check) and `wrapping_*` / `saturating_*`
// helpers, but no fire-and-forget panic-on-overflow surface. Adopters
// who wanted "compute-or-die" ergonomics had to write a flag-check
// after EVERY arithmetic op, which made the strict path so verbose
// that real code skipped it -- the silent-wrap hazard kept biting.
//
// New surface (v0.3.207):
//   panic_add(a, b) -> i64    panics on i64 overflow
//   panic_sub(a, b) -> i64    panics on i64 overflow
//   panic_mul(a, b) -> i64    panics on i64 overflow
//   panic_div(a, b) -> i64    panics on / 0 or i64::MIN / -1
//   panic_rem(a, b) -> i64    panics on % 0
//   panic_neg(v)    -> i64    panics on -(i64::MIN)
//
// Adopters can now write `let r = panic_add(panic_mul(a, b), c);`
// for the "no silent miscompute" arithmetic path. Wrapping and
// saturating remain available for code that explicitly wants them.
//
// This fixture exercises the success path; the panic path is in
// tests/fixtures/probe_panic_add_overflow.nr.

fn main() -> i64 {
    let a: i64 = 100;
    let b: i64 = 200;
    println!("{}", panic_add(a, b));        // 300
    println!("{}", panic_sub(b, a));        // 100
    println!("{}", panic_mul(a, b));        // 20000
    println!("{}", panic_div(b, a));        // 2
    println!("{}", panic_rem(b, 7));        // 4 (200 % 7)
    println!("{}", panic_neg(a));           // -100
    return 0;
}
