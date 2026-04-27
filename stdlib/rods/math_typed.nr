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

// v0.3.230 — NUC-IMPROVE-007: typed special functions for exact SciPy
// stats p-values. C99 erf/erfc/lgamma/tgamma plus Numerical Recipes
// continued-fraction incomplete-beta for Student-t and related families.
// Returns NaN bits on invalid input (a<=0, b<=0, x out of [0,1] for
// betainc; df<=0 for student_t_sf2).
fn erf_f64(x: f64) -> f64 { return f64_erf(x); }
fn erfc_f64(x: f64) -> f64 { return f64_erfc(x); }
fn lgamma_f64(x: f64) -> f64 { return f64_lgamma(x); }
fn gamma_f64(x: f64) -> f64 { return f64_tgamma(x); }
fn betainc_f64(x: f64, a: f64, b: f64) -> f64 { return f64_betainc(x, a, b); }
fn student_t_sf2_f64(t: f64, df: f64) -> f64 { return f64_student_t_sf2(t, df); }
fn norm_cdf_f64(x: f64) -> f64 { return f64_norm_cdf(x); }
fn norm_sf_f64(x: f64) -> f64 { return f64_norm_sf(x); }
