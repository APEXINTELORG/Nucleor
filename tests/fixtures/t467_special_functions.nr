// t467_special_functions.nr -- v0.3.230 NUC-IMPROVE-007 fixture.
//
// Typed special functions for exact SciPy stats parity:
//   erf, erfc, lgamma, gamma, betainc (regularized incomplete beta),
//   student_t_sf2 (two-sided Student-t survival), norm_cdf, norm_sf.
//
// Reference values from scipy/Wolfram Alpha:
//   erf(0)         = 0
//   erf(1)         ≈ 0.842700793
//   erfc(0)        = 1
//   lgamma(1)      = 0
//   lgamma(5)      ≈ 3.178053830
//   gamma(5)       = 24
//   norm_cdf(0)    = 0.5
//   norm_sf(0)     = 0.5
//   norm_cdf(1.96) ≈ 0.97500210  (the classic 95% CI bound)
//   student_t_sf2(2.0, df=10) ≈ 0.07338  (two-sided p for t=2 at df=10)

import "stdlib/rods/math_typed.nr"

fn main() -> i64 {
    println!("{}", erf_f64(0.0));            // 0
    println!("{}", erf_f64(1.0));            // ~0.842701
    println!("{}", erfc_f64(0.0));           // 1
    println!("{}", lgamma_f64(1.0));         // 0
    println!("{}", lgamma_f64(5.0));         // ~3.17805
    println!("{}", gamma_f64(5.0));          // 24
    println!("{}", norm_cdf_f64(0.0));       // 0.5
    println!("{}", norm_sf_f64(0.0));        // 0.5
    println!("{}", norm_cdf_f64(1.96));      // ~0.97500
    println!("{}", student_t_sf2_f64(2.0, 10.0));  // ~0.07338
    return 0;
}
