// t421_i64_min_const_fold.nr — v0.3.146 regression fixture.
//
// Pre-v0.3.146, str_from_int returned just "-" for i64::MIN
// (-9223372036854775808). The function negates `val` before the
// digit-extract loop (`if val < 0 { val = 0 - val; }`). For MIN_I64,
// `0 - MIN_I64` overflows back to MIN_I64 (because -MIN_I64 doesn't
// fit in signed i64). The `while val > 0` loop never executed
// (val stayed negative), `s` ended as "", then the `n < 0` branch
// prepended "-" and we returned just "-".
//
// Manifested as a CLANG ERROR rather than a silent miscompute:
// any const-fold that produced MIN_I64 (e.g. literal MAX_I64 + 1)
// emitted invalid LLVM IR like `add i64 -, 0`, and clang rejected
// with `expected value token`. Adopters who wrote i64::MAX + 1
// in their code (overflow-test scaffolding, sentinel-value
// helpers, integer-bounds checks) saw a clang error pointing at
// generated IR they didn't write -- confusing failure mode.
//
// Same hazard class as the v0.3.137-v0.3.145 silent-miscompute
// series: a real expression you wrote produces a confusing failure
// instead of a clean result.
//
// Fix: special-case n == MIN_I64 in str_from_int -- return the
// pre-formatted string "-9223372036854775808" and skip the loop.
// Mirrored in nucleor_tools_suite.nr.
//
// Returns 42 if both i64::MAX + 1 and i64::MIN as a literal lower
// to valid IR. Any pre-fix would error at clang link.

fn main() -> i64 {
    let max_i64: i64 = 9223372036854775807;
    let plus: i64 = max_i64 + 1;
    // plus is i64::MIN by wrapping. The const-fold computed this at
    // compile time and tried to format it via str_from_int -- pre-fix
    // produced "-" and clang failed.
    if plus < 0 { return 42; };
    return 99;
}
