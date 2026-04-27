// =====================================================
// rods/math_typed_special — Typed f64 special functions (NUC-IMPROVE-007)
// =====================================================
// Import: import "stdlib/rods/math_typed_special.nr"
//
// Typed `f64` wrappers around the SciPy-style special functions
// shipped in nucleor_llvm_rt.c. Split out from `math_typed.nr` in
// v0.3.232 (NUC-FEEDBACK-011) so importing the base typed-math rod
// does NOT require a v0.3.230+ compiler at link time.
//
// Adopters who explicitly want erf/lgamma/betainc/etc must:
//   1) Upgrade bin/nucleor.exe to >= v0.3.230 (the release that
//      added the f64_erf / f64_lgamma / f64_betainc / etc entries
//      to the compiler's get_rt_name table).
//   2) Add `import "stdlib/rods/math_typed_special.nr"` alongside
//      the existing `import "stdlib/rods/math_typed.nr"`.
//
// Available:
//   erf_f64(x)  -> f64
//   erfc_f64(x) -> f64
//   lgamma_f64(x) -> f64
//   gamma_f64(x)  -> f64                           — true Γ(x), via tgamma
//   betainc_f64(x, a, b) -> f64                    — regularized I_x(a,b)
//   student_t_sf2_f64(t, df) -> f64                — two-sided Student-t SF
//   norm_cdf_f64(x) -> f64                          — standard normal CDF
//   norm_sf_f64(x)  -> f64                          — standard normal SF
// =====================================================

fn erf_f64(x: f64) -> f64 {
    return f64_erf(x);
}

fn erfc_f64(x: f64) -> f64 {
    return f64_erfc(x);
}

fn lgamma_f64(x: f64) -> f64 {
    return f64_lgamma(x);
}

fn gamma_f64(x: f64) -> f64 {
    return f64_tgamma(x);
}

fn betainc_f64(x: f64, a: f64, b: f64) -> f64 {
    return f64_betainc(x, a, b);
}

fn student_t_sf2_f64(t: f64, df: f64) -> f64 {
    return f64_student_t_sf2(t, df);
}

fn norm_cdf_f64(x: f64) -> f64 {
    return f64_norm_cdf(x);
}

fn norm_sf_f64(x: f64) -> f64 {
    return f64_norm_sf(x);
}
