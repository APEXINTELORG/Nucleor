// t347_closure_capture.nr — v0.3.72 regression fixture.
//
// Pins closure-with-capture link-time correctness. Pre-v0.3.72,
// every closure that captured an outer variable failed at clang
// link with "unresolved external symbol __nucleor_capture_set /
// __nucleor_capture_get" — the codegen emitted calls to those
// runtime helpers but the helpers were never defined in
// nucleor_llvm_rt.c. v0.3.72 adds the helpers (a flat 8192×32
// capture table) so the let-bound closure-capture path works
// end-to-end.
//
// Returns 1 + 2 + 4 + 8 = 15 if all four captured-closure forms
// link, run, and return the right value.
//
// Known v1 boundary (NOT covered here): inline closures passed
// directly to .map / .filter / .fold (`v.map(|x| x * captured)`)
// go through a separate source preprocessor path that synthesizes
// the body as a top-level fn without capture detection — those
// still fail at compile/link. Workaround: lift the closure to a
// let binding (`let f = |x| x * captured; v.map(f)`). Tracked
// for a v0.4 parser/preprocessor refactor.

fn main() -> i64 {
    let mut score: i64 = 0;

    // 1) Single capture, return computed result
    let factor: i64 = 3;
    let mul3 = |x: i64| x * factor;
    if mul3(7) == 21 { score = score + 1; };

    // 2) Two captures, mixed in one expression
    let offset: i64 = 5;
    let mul3_off = |x: i64| x * factor + offset;
    if mul3_off(10) == 35 { score = score + 2; };

    // 3) Capture + reused multiple times in body
    let combine = |x: i64| x * factor + x * factor;
    if combine(4) == 24 { score = score + 4; };

    // 4) Closure stored, captured by structurally distinct closure
    //    (verifies capture-table slots don't alias across closures)
    let m1 = |x: i64| x * factor;
    let m2 = |x: i64| x + offset;
    if m1(2) + m2(3) == 14 { score = score + 8; };

    return score;  // expect 15
}
