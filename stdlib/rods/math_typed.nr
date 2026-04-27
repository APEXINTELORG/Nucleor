// =====================================================
// rods/math_typed — Typed f64 elementary math wrappers (NUC-IMPROVE-005)
// =====================================================
// Import: import "stdlib/rods/math_typed.nr"
//
// Typed `f64` wrappers around the bit-pattern math runtime helpers
// already shipped in nucleor_llvm_rt.c. Lets ML/scientific code
// using typed `f64` arithmetic call elementary functions directly
// without manual `f64_from_bits` / `f64_to_bits` plumbing.
//
// At the runtime ABI level Nucleor's f64 IS the i64 bit pattern,
// so each wrapper is a one-line identity around the existing
// helper. The named entries document intent at the call site and
// give type-checkers + IDEs the right signatures to validate.
//
// Available:
//   sqrt_f64(x) -> f64
//   exp_f64(x)  -> f64    — e^x
//   log_f64(x)  -> f64    — natural log
//   tanh_f64(x) -> f64
//   sin_f64(x)  -> f64
//   cos_f64(x)  -> f64
//   pow_f64(base, exp) -> f64
// =====================================================

fn sqrt_f64(x: f64) -> f64 {
    return sqrt(x);
}

fn exp_f64(x: f64) -> f64 {
    return exp(x);
}

fn log_f64(x: f64) -> f64 {
    return log(x);
}

fn tanh_f64(x: f64) -> f64 {
    return tanh(x);
}

fn sin_f64(x: f64) -> f64 {
    return sin(x);
}

fn cos_f64(x: f64) -> f64 {
    return cos(x);
}

fn pow_f64(base: f64, exp: f64) -> f64 {
    return pow(base, exp);
}

// v0.3.232 — NUC-FEEDBACK-011: special functions moved to a separate
// rod (`stdlib/rods/math_typed_special.nr`). The v0.3.230 inclusion
// of betainc/erf/lgamma/etc wrappers in this file made any program
// importing math_typed.nr require a v0.3.230+ compiler at link time
// (the compiler's get_rt_name table needs the new mappings).
// Splitting them keeps math_typed.nr backward-compatible while
// adopters who explicitly want the special functions can:
//   import "stdlib/rods/math_typed_special.nr"
// after upgrading their bin/nucleor.exe to >= v0.3.230.
