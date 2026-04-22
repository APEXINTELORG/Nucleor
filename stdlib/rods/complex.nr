// =====================================================
// rods/complex — Complex number arithmetic (via C FFI)
// =====================================================
// Import: import "stdlib/rods/complex.nr"
//
// Complex numbers are heap-allocated pairs of f64 values
// (real, imaginary), passed as i64 handles.
//
// Provides:
//   Constructors:  cx_new, cx_real, cx_imag, cx_from_real, cx_from_polar
//   Arithmetic:    cx_add, cx_sub, cx_mul, cx_div, cx_scale, cx_neg
//   Properties:    cx_conj, cx_abs, cx_abs_sq, cx_phase
//   Transcendental: cx_exp, cx_sqrt, cx_log, cx_pow, cx_sin, cx_cos
//   Utility:       cx_approx_eq, cx_to_str
//   Constants:     cx_zero, cx_one, cx_i
//   f64 helpers:   f64, f64_from_int, f64_to_int, f64_add, f64_sub,
//                  f64_mul, f64_div, f64_neg, f64_sqrt, f64_sin, f64_cos,
//                  f64_exp, f64_log, f64_pow, f64_abs, f64_pi, f64_e,
//                  f64_sqrt2, f64_inv_sqrt2
//   Random:        rng_seed, rng_f64, rng_range, rng_normal
// =====================================================

#cfile "complex_rt.c"

// --- f64 helpers (bit-cast through i64) ---

extern fn rods_f64_encode(integer_part: i64, frac_millionths: i64) -> i64;
extern fn rods_f64_from_int(x: i64) -> i64;
extern fn rods_f64_to_int(x: i64) -> i64;
extern fn rods_f64_add(a: i64, b: i64) -> i64;
extern fn rods_f64_sub(a: i64, b: i64) -> i64;
extern fn rods_f64_mul(a: i64, b: i64) -> i64;
extern fn rods_f64_div(a: i64, b: i64) -> i64;
extern fn rods_f64_neg(a: i64) -> i64;
extern fn rods_f64_lt(a: i64, b: i64) -> i64;
extern fn rods_f64_gt(a: i64, b: i64) -> i64;
extern fn rods_f64_eq(a: i64, b: i64) -> i64;
extern fn rods_f64_sqrt(a: i64) -> i64;
extern fn rods_f64_sin(a: i64) -> i64;
extern fn rods_f64_cos(a: i64) -> i64;
extern fn rods_f64_atan2(y: i64, x: i64) -> i64;
extern fn rods_f64_exp(a: i64) -> i64;
extern fn rods_f64_log(a: i64) -> i64;
extern fn rods_f64_pow(a: i64, b: i64) -> i64;
extern fn rods_f64_abs(a: i64) -> i64;
extern fn rods_f64_floor(a: i64) -> i64;
extern fn rods_f64_ceil(a: i64) -> i64;
extern fn rods_f64_pi() -> i64;
extern fn rods_f64_e() -> i64;
extern fn rods_f64_tau() -> i64;
extern fn rods_f64_sqrt2() -> i64;
extern fn rods_f64_inv_sqrt2() -> i64;
extern fn rods_rng_seed(s: i64);
extern fn rods_rng_f64() -> i64;
extern fn rods_rng_range(max: i64) -> i64;
extern fn rods_rng_normal() -> i64;

// Encode an f64 from integer + fractional millionths: f64(3, 141593) = 3.141593
fn f64(integer_part: i64, frac_millionths: i64) -> i64 {
    return rods_f64_encode(integer_part, frac_millionths);
}

fn f64_from_int(x: i64) -> i64 { return rods_f64_from_int(x); }
fn f64_to_int(x: i64) -> i64 { return rods_f64_to_int(x); }
fn f64_add(a: i64, b: i64) -> i64 { return rods_f64_add(a, b); }
fn f64_sub(a: i64, b: i64) -> i64 { return rods_f64_sub(a, b); }
fn f64_mul(a: i64, b: i64) -> i64 { return rods_f64_mul(a, b); }
fn f64_div(a: i64, b: i64) -> i64 { return rods_f64_div(a, b); }
fn f64_neg(a: i64) -> i64 { return rods_f64_neg(a); }
fn f64_lt(a: i64, b: i64) -> i64 { return rods_f64_lt(a, b); }
fn f64_gt(a: i64, b: i64) -> i64 { return rods_f64_gt(a, b); }
fn f64_eq(a: i64, b: i64) -> i64 { return rods_f64_eq(a, b); }
fn f64_sqrt(a: i64) -> i64 { return rods_f64_sqrt(a); }
fn f64_sin(a: i64) -> i64 { return rods_f64_sin(a); }
fn f64_cos(a: i64) -> i64 { return rods_f64_cos(a); }
fn f64_atan2(y: i64, x: i64) -> i64 { return rods_f64_atan2(y, x); }
fn f64_exp(a: i64) -> i64 { return rods_f64_exp(a); }
fn f64_log(a: i64) -> i64 { return rods_f64_log(a); }
fn f64_pow(a: i64, b: i64) -> i64 { return rods_f64_pow(a, b); }
fn f64_abs(a: i64) -> i64 { return rods_f64_abs(a); }
fn f64_floor(a: i64) -> i64 { return rods_f64_floor(a); }
fn f64_ceil(a: i64) -> i64 { return rods_f64_ceil(a); }
fn f64_pi() -> i64 { return rods_f64_pi(); }
fn f64_e() -> i64 { return rods_f64_e(); }
fn f64_tau() -> i64 { return rods_f64_tau(); }
fn f64_sqrt2() -> i64 { return rods_f64_sqrt2(); }
fn f64_inv_sqrt2() -> i64 { return rods_f64_inv_sqrt2(); }

// --- Complex number externs ---

extern fn rods_complex_new(re: i64, im: i64) -> i64;
extern fn rods_complex_from_real(re: i64) -> i64;
extern fn rods_complex_from_polar(r: i64, theta: i64) -> i64;
extern fn rods_complex_real(c: i64) -> i64;
extern fn rods_complex_imag(c: i64) -> i64;
extern fn rods_complex_add(c1: i64, c2: i64) -> i64;
extern fn rods_complex_sub(c1: i64, c2: i64) -> i64;
extern fn rods_complex_mul(c1: i64, c2: i64) -> i64;
extern fn rods_complex_div(c1: i64, c2: i64) -> i64;
extern fn rods_complex_scale(c: i64, s: i64) -> i64;
extern fn rods_complex_neg(c: i64) -> i64;
extern fn rods_complex_conj(c: i64) -> i64;
extern fn rods_complex_abs(c: i64) -> i64;
extern fn rods_complex_abs_sq(c: i64) -> i64;
extern fn rods_complex_phase(c: i64) -> i64;
extern fn rods_complex_exp(c: i64) -> i64;
extern fn rods_complex_sqrt(c: i64) -> i64;
extern fn rods_complex_log(c: i64) -> i64;
extern fn rods_complex_pow(base: i64, exponent: i64) -> i64;
extern fn rods_complex_sin(c: i64) -> i64;
extern fn rods_complex_cos(c: i64) -> i64;
extern fn rods_complex_approx_eq(c1: i64, c2: i64, eps: i64) -> i64;
extern fn rods_complex_to_str(c: i64) -> str;
extern fn rods_complex_zero() -> i64;
extern fn rods_complex_one() -> i64;
extern fn rods_complex_i() -> i64;

// === Constructors ===

// Create complex number from real and imaginary f64 values
fn cx_new(re: i64, im: i64) -> i64 {
    return rods_complex_new(re, im);
}

// Create complex from real value only (imag = 0)
fn cx_from_real(re: i64) -> i64 {
    return rods_complex_from_real(re);
}

// Create complex from polar form: r * e^(i*theta)
fn cx_from_polar(r: i64, theta: i64) -> i64 {
    return rods_complex_from_polar(r, theta);
}

// === Accessors ===

// Get real part (returns f64 as i64)
fn cx_real(c: i64) -> i64 {
    return rods_complex_real(c);
}

// Get imaginary part (returns f64 as i64)
fn cx_imag(c: i64) -> i64 {
    return rods_complex_imag(c);
}

// === Arithmetic ===

// Complex addition
fn cx_add(c1: i64, c2: i64) -> i64 {
    return rods_complex_add(c1, c2);
}

// Complex subtraction
fn cx_sub(c1: i64, c2: i64) -> i64 {
    return rods_complex_sub(c1, c2);
}

// Complex multiplication
fn cx_mul(c1: i64, c2: i64) -> i64 {
    return rods_complex_mul(c1, c2);
}

// Complex division
fn cx_div(c1: i64, c2: i64) -> i64 {
    return rods_complex_div(c1, c2);
}

// Scalar multiplication: s * z
fn cx_scale(c: i64, s: i64) -> i64 {
    return rods_complex_scale(c, s);
}

// Negate: -z
fn cx_neg(c: i64) -> i64 {
    return rods_complex_neg(c);
}

// === Properties ===

// Complex conjugate: (a+bi)* = a-bi
fn cx_conj(c: i64) -> i64 {
    return rods_complex_conj(c);
}

// Magnitude: |z| = sqrt(a^2 + b^2)
fn cx_abs(c: i64) -> i64 {
    return rods_complex_abs(c);
}

// Squared magnitude: |z|^2 = a^2 + b^2 (probability in quantum mechanics)
fn cx_abs_sq(c: i64) -> i64 {
    return rods_complex_abs_sq(c);
}

// Phase (argument): atan2(b, a)
fn cx_phase(c: i64) -> i64 {
    return rods_complex_phase(c);
}

// === Transcendental Functions ===

// Complex exponential: e^z = e^a * (cos(b) + i*sin(b))
fn cx_exp(c: i64) -> i64 {
    return rods_complex_exp(c);
}

// Complex square root
fn cx_sqrt(c: i64) -> i64 {
    return rods_complex_sqrt(c);
}

// Complex natural logarithm
fn cx_log(c: i64) -> i64 {
    return rods_complex_log(c);
}

// Complex power: base^exponent
fn cx_pow(base: i64, exponent: i64) -> i64 {
    return rods_complex_pow(base, exponent);
}

// Complex sine
fn cx_sin(c: i64) -> i64 {
    return rods_complex_sin(c);
}

// Complex cosine
fn cx_cos(c: i64) -> i64 {
    return rods_complex_cos(c);
}

// === Utility ===

// Approximate equality within epsilon
fn cx_approx_eq(c1: i64, c2: i64, eps: i64) -> i64 {
    return rods_complex_approx_eq(c1, c2, eps);
}

// Format as string: "a+bi"
fn cx_to_str(c: i64) -> str {
    return rods_complex_to_str(c);
}

// === Constants ===

// 0 + 0i
fn cx_zero() -> i64 { return rods_complex_zero(); }

// 1 + 0i
fn cx_one() -> i64 { return rods_complex_one(); }

// 0 + 1i
fn cx_i() -> i64 { return rods_complex_i(); }

// === Random Number Generation (xoshiro256** PRNG) ===

// Seed the RNG (call once before using rng_f64/rng_range/rng_normal)
fn rng_seed(s: i64) { rods_rng_seed(s); }

// Uniform random f64 in [0, 1) — for measurement sampling
fn rng_f64() -> i64 { return rods_rng_f64(); }

// Uniform random integer in [0, max) — for discrete sampling
fn rng_range(max: i64) -> i64 { return rods_rng_range(max); }

// Standard normal N(0,1) — Box-Muller transform
fn rng_normal() -> i64 { return rods_rng_normal(); }
