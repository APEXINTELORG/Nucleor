// repro_v53_unwrap_on_non_option_guard.nr
//
// v0.4.53 NUC-FEEDBACK silent-undefined-symbol guard for
// Option/Result methods called on non-Option receivers.
//
// Pre-v0.4.53 `x.unwrap()` (and .expect / .unwrap_or / .ok / .err /
// .is_ok / .is_err / .is_some / .is_none / .and_then / .or_else)
// on a bare i64 (or any non-Option/Result receiver) lowered the
// method call to `vec_unwrap(x)` (etc.) — there's no such runtime
// helper, so the build failed late at clang link with
// `undefined value '@vec_unwrap'`. Adopters got a confusing
// LLVM-IR error pointing at compiler-emitted text rather than
// their source.
//
// v0.4.53 detects the dispatch fallback when the method name is
// in the Option/Result method list AND the user-defined-impl
// lookup misses, and panics with a clear hint.

fn main() -> i64 {
    let x: i64 = 42;
    let y: i64 = x.unwrap();    // panic expected (was vec_unwrap link error)
    println!("{}", y);
    return 0;
}
