// v0.7.77 consolidated negative fixture — two unrelated wrong-class
// halts both anchored in `parse_stmt` at statement start:
//
//   - `yield <expr>;`           — Rust nightly generator/coroutine
//                                 syntax. Pre-fix lexed `yield` as
//                                 a plain ident and parsed it as a
//                                 fn call to `yield(...)`,
//                                 producing wrong-class TYP-005 at
//                                 clang link.
//
//   - `(a, b) = (1, 2);`        — Rust 1.59+ destructuring
//                                 assignment to already-bound
//                                 variables. Pre-fix the `(a, b)`
//                                 parsed as a parenthesized tuple
//                                 expr and the trailing `=` was
//                                 silently dropped — SILENT
//                                 MISCOMPUTE: `a` and `b` kept
//                                 their previous values (probe
//                                 verified rc=0 instead of 1020).
//
// Both halts now fire cleanly at statement start. To validate the
// destructuring-assignment form, swap the body to:
//   let mut a: i64 = 0; let mut b: i64 = 0; (a, b) = (10, 20); return a;
fn gen() -> i64 {
    yield 1;
    return 2;
}

fn main() -> i64 {
    return gen();
}
