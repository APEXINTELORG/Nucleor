// rods/complex runtime — Complex number arithmetic for Nucleor
// Complex numbers are represented as two i64 values (bit-cast f64 real, imag)
// All functions take and return i64 (which are bit-cast doubles)

#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

// Helper: reinterpret i64 as f64
static double i2f(long long x) {
    double d;
    memcpy(&d, &x, sizeof(double));
    return d;
}

// Helper: reinterpret f64 as i64
static long long f2i(double d) {
    long long x;
    memcpy(&x, &d, sizeof(long long));
    return x;
}

// === Constructors / Accessors ===

// Pack real and imag into a heap-allocated pair, return pointer as i64
long long rods_complex_new(long long re, long long im) {
    long long *p = (long long *)malloc(2 * sizeof(long long));
    p[0] = re;
    p[1] = im;
    return (long long)p;
}

// Create from a real value (imag = 0)
long long rods_complex_from_real(long long re) {
    long long *p = (long long *)malloc(2 * sizeof(long long));
    p[0] = re;
    p[1] = f2i(0.0);
    return (long long)p;
}

// Create from polar form: r * (cos(theta) + i*sin(theta))
long long rods_complex_from_polar(long long r_bits, long long theta_bits) {
    double r = i2f(r_bits);
    double theta = i2f(theta_bits);
    long long *p = (long long *)malloc(2 * sizeof(long long));
    p[0] = f2i(r * cos(theta));
    p[1] = f2i(r * sin(theta));
    return (long long)p;
}

// Get real part as i64 (bit-cast f64)
long long rods_complex_real(long long c) {
    long long *p = (long long *)c;
    return p[0];
}

// Get imaginary part as i64 (bit-cast f64)
long long rods_complex_imag(long long c) {
    long long *p = (long long *)c;
    return p[1];
}

// === Basic Arithmetic ===

// (a+bi) + (c+di) = (a+c) + (b+d)i
long long rods_complex_add(long long c1, long long c2) {
    long long *p1 = (long long *)c1;
    long long *p2 = (long long *)c2;
    double re = i2f(p1[0]) + i2f(p2[0]);
    double im = i2f(p1[1]) + i2f(p2[1]);
    return rods_complex_new(f2i(re), f2i(im));
}

// (a+bi) - (c+di) = (a-c) + (b-d)i
long long rods_complex_sub(long long c1, long long c2) {
    long long *p1 = (long long *)c1;
    long long *p2 = (long long *)c2;
    double re = i2f(p1[0]) - i2f(p2[0]);
    double im = i2f(p1[1]) - i2f(p2[1]);
    return rods_complex_new(f2i(re), f2i(im));
}

// (a+bi) * (c+di) = (ac-bd) + (ad+bc)i
long long rods_complex_mul(long long c1, long long c2) {
    long long *p1 = (long long *)c1;
    long long *p2 = (long long *)c2;
    double a = i2f(p1[0]), b = i2f(p1[1]);
    double c = i2f(p2[0]), d = i2f(p2[1]);
    double re = a * c - b * d;
    double im = a * d + b * c;
    return rods_complex_new(f2i(re), f2i(im));
}

// (a+bi) / (c+di) — R09-D3 Phase 1 (v0.8.276): Smith's algorithm for
// numerical stability. Direct `(a*c+b*d) / (c^2+d^2)` overflows when
// |c| or |d| is large enough that c^2 exceeds DBL_MAX, and underflows
// when both are very small. Smith's variant scales by the larger of
// the two magnitudes to stay in the well-conditioned regime.
long long rods_complex_div(long long c1, long long c2) {
    long long *p1 = (long long *)c1;
    long long *p2 = (long long *)c2;
    double a = i2f(p1[0]), b = i2f(p1[1]);
    double c = i2f(p2[0]), d = i2f(p2[1]);
    double abs_c = c < 0 ? -c : c;
    double abs_d = d < 0 ? -d : d;
    double re, im;
    if (abs_c >= abs_d) {
        double r = d / c;
        double denom = c + r * d;
        re = (a + r * b) / denom;
        im = (b - r * a) / denom;
    } else {
        double r = c / d;
        double denom = d + r * c;
        re = (a * r + b) / denom;
        im = (b * r - a) / denom;
    }
    return rods_complex_new(f2i(re), f2i(im));
}

// Scalar multiply: s * (a+bi) = (s*a) + (s*b)i
long long rods_complex_scale(long long c, long long s_bits) {
    long long *p = (long long *)c;
    double s = i2f(s_bits);
    double re = i2f(p[0]) * s;
    double im = i2f(p[1]) * s;
    return rods_complex_new(f2i(re), f2i(im));
}

// Negate: -(a+bi) = (-a) + (-b)i
long long rods_complex_neg(long long c) {
    long long *p = (long long *)c;
    return rods_complex_new(f2i(-i2f(p[0])), f2i(-i2f(p[1])));
}

// === Properties ===

// Conjugate: (a+bi)* = a - bi
long long rods_complex_conj(long long c) {
    long long *p = (long long *)c;
    return rods_complex_new(p[0], f2i(-i2f(p[1])));
}

// Magnitude (absolute value): |a+bi|.
// R09-D3 Phase 1 (v0.8.276): use `hypot(a, b)` instead of
// `sqrt(a*a + b*b)`. Direct sqrt overflows for large |a| or |b|
// (a^2 exceeds DBL_MAX) and underflows for very small. `hypot` is
// the C99 standard library implementation specifically scaled to
// avoid both ends.
long long rods_complex_abs(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    return f2i(hypot(a, b));
}

// Squared magnitude: |a+bi|^2 = a^2 + b^2 (avoids sqrt for probability)
long long rods_complex_abs_sq(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    return f2i(a * a + b * b);
}

// Phase (argument): atan2(b, a)
long long rods_complex_phase(long long c) {
    long long *p = (long long *)c;
    return f2i(atan2(i2f(p[1]), i2f(p[0])));
}

// === Transcendental Functions ===

// e^(a+bi) = e^a * (cos(b) + i*sin(b))
long long rods_complex_exp(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    double ea = exp(a);
    return rods_complex_new(f2i(ea * cos(b)), f2i(ea * sin(b)));
}

// sqrt(a+bi) = sqrt(r) * (cos(theta/2) + i*sin(theta/2))
long long rods_complex_sqrt(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    double r = sqrt(a * a + b * b);
    double theta = atan2(b, a);
    double sr = sqrt(r);
    return rods_complex_new(f2i(sr * cos(theta / 2.0)), f2i(sr * sin(theta / 2.0)));
}

// ln(a+bi) = ln|z| + i*arg(z).
// R09-D3 Phase 1 (v0.8.276): magnitude via `hypot(a, b)` (stable
// at extremes). Direct `sqrt(a*a + b*b)` had the same overflow/
// underflow issues as `rods_complex_abs`.
long long rods_complex_log(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    double r = hypot(a, b);
    double theta = atan2(b, a);
    return rods_complex_new(f2i(log(r)), f2i(theta));
}

// z^w = e^(w * ln(z))
long long rods_complex_pow(long long base, long long exponent) {
    long long lnz = rods_complex_log(base);
    long long w_lnz = rods_complex_mul(exponent, lnz);
    return rods_complex_exp(w_lnz);
}

// sin(a+bi) = sin(a)cosh(b) + i*cos(a)sinh(b)
long long rods_complex_sin(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    return rods_complex_new(f2i(sin(a) * cosh(b)), f2i(cos(a) * sinh(b)));
}

// cos(a+bi) = cos(a)cosh(b) - i*sin(a)sinh(b)
long long rods_complex_cos(long long c) {
    long long *p = (long long *)c;
    double a = i2f(p[0]), b = i2f(p[1]);
    return rods_complex_new(f2i(cos(a) * cosh(b)), f2i(-sin(a) * sinh(b)));
}

// === Comparison / Utility ===

// Approximate equality within epsilon
long long rods_complex_approx_eq(long long c1, long long c2, long long eps_bits) {
    long long *p1 = (long long *)c1;
    long long *p2 = (long long *)c2;
    double eps = i2f(eps_bits);
    double dr = fabs(i2f(p1[0]) - i2f(p2[0]));
    double di = fabs(i2f(p1[1]) - i2f(p2[1]));
    return (dr < eps && di < eps) ? 1 : 0;
}

// Format as string: "a+bi" or "a-bi"
const char *rods_complex_to_str(long long c) {
    long long *p = (long long *)c;
    double re = i2f(p[0]), im = i2f(p[1]);
    char *buf = (char *)malloc(128);
    if (im >= 0.0) {
        snprintf(buf, 128, "%.6f+%.6fi", re, im);
    } else {
        snprintf(buf, 128, "%.6f%.6fi", re, im);
    }
    return buf;
}

// === Constants (returned as heap-allocated complex) ===

// 0 + 0i
long long rods_complex_zero(void) {
    return rods_complex_new(f2i(0.0), f2i(0.0));
}

// 1 + 0i
long long rods_complex_one(void) {
    return rods_complex_new(f2i(1.0), f2i(0.0));
}

// 0 + 1i
long long rods_complex_i(void) {
    return rods_complex_new(f2i(0.0), f2i(1.0));
}

// === f64 bit-cast helpers (for Nucleor code to create f64 literals) ===

long long rods_f64_encode(long long integer_part, long long frac_millionths) {
    double d = (double)integer_part + (double)frac_millionths / 1000000.0;
    return f2i(d);
}

long long rods_f64_from_int(long long x) {
    return f2i((double)x);
}

long long rods_f64_to_int(long long x) {
    return (long long)i2f(x);
}

long long rods_f64_add(long long a, long long b) { return f2i(i2f(a) + i2f(b)); }
long long rods_f64_sub(long long a, long long b) { return f2i(i2f(a) - i2f(b)); }
long long rods_f64_mul(long long a, long long b) { return f2i(i2f(a) * i2f(b)); }
long long rods_f64_div(long long a, long long b) { return f2i(i2f(a) / i2f(b)); }
long long rods_f64_neg(long long a) { return f2i(-i2f(a)); }
long long rods_f64_lt(long long a, long long b) { return i2f(a) < i2f(b) ? 1 : 0; }
long long rods_f64_gt(long long a, long long b) { return i2f(a) > i2f(b) ? 1 : 0; }
long long rods_f64_eq(long long a, long long b) { return i2f(a) == i2f(b) ? 1 : 0; }
long long rods_f64_sqrt(long long a) { return f2i(sqrt(i2f(a))); }
long long rods_f64_sin(long long a) { return f2i(sin(i2f(a))); }
long long rods_f64_cos(long long a) { return f2i(cos(i2f(a))); }
long long rods_f64_atan2(long long y, long long x) { return f2i(atan2(i2f(y), i2f(x))); }
long long rods_f64_exp(long long a) { return f2i(exp(i2f(a))); }
long long rods_f64_log(long long a) { return f2i(log(i2f(a))); }
long long rods_f64_pow(long long a, long long b) { return f2i(pow(i2f(a), i2f(b))); }
long long rods_f64_abs(long long a) { return f2i(fabs(i2f(a))); }
long long rods_f64_floor(long long a) { return f2i(floor(i2f(a))); }
long long rods_f64_ceil(long long a) { return f2i(ceil(i2f(a))); }

// Constants
long long rods_f64_pi(void) { return f2i(3.14159265358979323846); }
long long rods_f64_e(void) { return f2i(2.71828182845904523536); }
long long rods_f64_tau(void) { return f2i(6.28318530717958647692); }
long long rods_f64_sqrt2(void) { return f2i(1.41421356237309504880); }
long long rods_f64_inv_sqrt2(void) { return f2i(0.70710678118654752440); }

// === Random number generation (xoshiro256** PRNG) ===

static unsigned long long rng_state[4] = {
    0x180EC6D33CFD0ABALL, 0xD5A61266F0C9392CLL,
    0xA9582618E03FC9AALL, 0x39ABDC4529B1661CLL
};

static unsigned long long rng_rotl(unsigned long long x, int k) {
    return (x << k) | (x >> (64 - k));
}

void rods_rng_seed(long long s) {
    // SplitMix64 to initialize state from a single seed
    unsigned long long z = (unsigned long long)s;
    for (int i = 0; i < 4; i++) {
        z += 0x9E3779B97F4A7C15ULL;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
        rng_state[i] = z ^ (z >> 31);
    }
}

// Returns a uniform random u64
static unsigned long long rng_next(void) {
    unsigned long long *s = rng_state;
    unsigned long long result = rng_rotl(s[1] * 5, 7) * 9;
    unsigned long long t = s[1] << 17;
    s[2] ^= s[0];
    s[3] ^= s[1];
    s[1] ^= s[2];
    s[0] ^= s[3];
    s[2] ^= t;
    s[3] = rng_rotl(s[3], 45);
    return result;
}

// Uniform f64 in [0, 1)
long long rods_rng_f64(void) {
    unsigned long long x = rng_next() >> 11;
    double d = (double)x / 9007199254740992.0; // 2^53
    return f2i(d);
}

// Uniform i64 in [0, max)
long long rods_rng_range(long long max) {
    if (max <= 0) return 0;
    return (long long)(rng_next() % (unsigned long long)max);
}

// Normal distribution (Box-Muller transform)
long long rods_rng_normal(void) {
    unsigned long long x1 = rng_next() >> 11;
    unsigned long long x2 = rng_next() >> 11;
    double u1 = ((double)x1 + 1.0) / 9007199254740993.0; // (0, 1)
    double u2 = (double)x2 / 9007199254740992.0;          // [0, 1)
    double z = sqrt(-2.0 * log(u1)) * cos(6.28318530717958647692 * u2);
    return f2i(z);
}
