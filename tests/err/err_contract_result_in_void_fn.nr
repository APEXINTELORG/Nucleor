// RFC-0006 — `result` in `#[ensure]` on a void fn must reject at compile time.
//
// v0.4.272 closes silent-miscompute filed by probe agent
// 2026-05-01: a void fn (no return type) has no value to bind
// `result` against. Pre-fix, the ensure predicate ran against
// whatever the alloca slot held — typically zero-init, so
// `#[ensure(result == 0)]` "happened to pass" by coincidence;
// `#[ensure(result > 0)]` panicked CONTRACT-002 at runtime, both
// confusing wrong-error states. CONTRACT-008 names the void fn
// and the fix.
//
// EXPECT: build fails with CONTRACT-008.

#[ensure(result == 0)]
fn void_fn(x: i64) {
    print_int(x as i32);
}

fn main() -> i32 {
    void_fn(5);
    0
}
