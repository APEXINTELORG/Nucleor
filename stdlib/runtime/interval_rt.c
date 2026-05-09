// interval_rt.c — Rigorous Interval Arithmetic Engine for Computer-Assisted Proofs
//
// Every arithmetic operation produces guaranteed enclosures: the true mathematical
// result is ALWAYS contained in the returned interval [lo, hi].
//
// Uses IEEE 754 directed rounding: FE_DOWNWARD for lower bounds, FE_UPWARD for upper.
// This is the bridge between numerical simulation and mathematical proof.
//
// Compile: clang -c stdlib/runtime/interval_rt.c -o target/interval_rt.obj -O2
// NOTE: -O2 is safe with fesetround — the C standard guarantees FP rounding mode
//       is respected when #pragma STDC FENV_ACCESS ON is active.

#pragma STDC FENV_ACCESS ON

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include <fenv.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ---- FFI helpers ----
static double _mi2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _mf2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ---- Interval type ----
typedef struct {
    double lo;  // lower bound (computed with round-toward-negative-infinity)
    double hi;  // upper bound (computed with round-toward-positive-infinity)
} Interval;

// ---- Vec type (matches nucleor_llvm_rt.c) ----
/* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */

static NVec *nvec_new(void) {
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->data = (long long *)malloc(16 * sizeof(long long));
    v->len = 0; v->cap = 16;
    return v;
}
static void nvec_push(NVec *v, long long x) {
    if (!v) return;
    if (v->len >= v->cap) { v->cap *= 2; v->data = realloc(v->data, v->cap * sizeof(long long)); }
    v->data[v->len++] = x;
}
static long long nvec_get(NVec *v, int i) {
    if (!v || i < 0 || i >= v->len) return 0;
    return v->data[i];
}

// ---- Interval pool (handle-based allocation) ----
#define INTERVAL_POOL_SIZE 2000000
static Interval *interval_pool = NULL;
static int interval_next = 1;  // 0 = invalid handle

static void ensure_pool(void) {
    if (!interval_pool) {
        interval_pool = (Interval *)calloc(INTERVAL_POOL_SIZE, sizeof(Interval));
    }
}

// Reset pool to a checkpoint. All intervals with index >= checkpoint become invalid.
// Use to reclaim temporaries after each integration step.
long long nuc_interval_pool_checkpoint(void) {
    ensure_pool();
    return (long long)interval_next;
}

long long nuc_interval_pool_capacity(void) {
    ensure_pool();
    return (long long)(INTERVAL_POOL_SIZE - 1);
}

long long nuc_interval_pool_used(void) {
    ensure_pool();
    return (long long)(interval_next - 1);
}

long long nuc_interval_pool_remaining(void) {
    ensure_pool();
    return (long long)(INTERVAL_POOL_SIZE - interval_next);
}

long long nuc_interval_pool_preflight(long long count) {
    ensure_pool();
    if (count < 0) return 0;
    return (count <= (long long)(INTERVAL_POOL_SIZE - interval_next)) ? 1 : 0;
}

void nuc_interval_pool_reset(long long checkpoint) {
    int cp = (int)checkpoint;
    if (cp >= 1 && cp < INTERVAL_POOL_SIZE) {
        interval_next = cp;
    }
}

static long long iv_alloc(double lo, double hi) {
    ensure_pool();
    // R09-D2 Phase 1 (v0.8.277): fail closed on pool exhaustion.
    // Pre-v0.8.277 wrapped to slot 1, silently aliasing all
    // earlier handles still in caller scope — interval-containment
    // guarantees broke without diagnostic. Now returns 0 (the
    // canonical "invalid handle" — rejected by `iv_get`'s bounds
    // check). Adopters check `handle == 0` after iv_alloc and bail
    // safely. Phase 2 may add pool growth or freelist; Phase 1
    // prefers fail-closed over silent corruption.
    if (interval_next >= INTERVAL_POOL_SIZE) {
        return 0;
    }
    int idx = interval_next++;
    interval_pool[idx].lo = lo;
    interval_pool[idx].hi = hi;
    return (long long)idx;
}

static Interval *iv_get(long long handle) {
    ensure_pool();
    int idx = (int)handle;
    if (idx <= 0 || idx >= INTERVAL_POOL_SIZE) return NULL;
    return &interval_pool[idx];
}

// ---- Helper: min/max of 4 doubles ----
static double dmin4(double a, double b, double c, double d) {
    double m = a;
    if (b < m) m = b; if (c < m) m = c; if (d < m) m = d;
    return m;
}
static double dmax4(double a, double b, double c, double d) {
    double m = a;
    if (b > m) m = b; if (c > m) m = c; if (d > m) m = d;
    return m;
}

// ================================================================
//  PUBLIC API — Interval Arithmetic
// ================================================================

// Create interval [lo, hi]
long long nuc_interval_new(long long lo_bits, long long hi_bits) {
    double lo = _mi2f(lo_bits);
    double hi = _mi2f(hi_bits);
    if (lo > hi) { double t = lo; lo = hi; hi = t; }
    return iv_alloc(lo, hi);
}

// Create point interval [x, x]
long long nuc_interval_point(long long x_bits) {
    double x = _mi2f(x_bits);
    return iv_alloc(x, x);
}

// Get lower bound
long long nuc_interval_lo(long long handle) {
    Interval *iv = iv_get(handle);
    return iv ? _mf2i(iv->lo) : _mf2i(0.0);
}

// Get upper bound
long long nuc_interval_hi(long long handle) {
    Interval *iv = iv_get(handle);
    return iv ? _mf2i(iv->hi) : _mf2i(0.0);
}

// Width = hi - lo (rounded up)
long long nuc_interval_width(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return _mf2i(0.0);
    fesetround(FE_UPWARD);
    double w = iv->hi - iv->lo;
    fesetround(FE_TONEAREST);
    return _mf2i(w);
}

// Midpoint (not rigorous, just for display)
long long nuc_interval_midpoint(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return _mf2i(0.0);
    return _mf2i((iv->lo + iv->hi) * 0.5);
}

// Does interval contain value x?
long long nuc_interval_contains(long long handle, long long x_bits) {
    Interval *iv = iv_get(handle);
    double x = _mi2f(x_bits);
    if (!iv) return 0;
    return (x >= iv->lo && x <= iv->hi) ? 1 : 0;
}

// ---- Arithmetic operations with directed rounding ----

// Addition: [a,b] + [c,d] = [a+c (round down), b+d (round up)]
long long nuc_interval_add(long long h1, long long h2) {
    Interval *a = iv_get(h1), *b = iv_get(h2);
    if (!a || !b) return iv_alloc(0, 0);
    fesetround(FE_DOWNWARD);
    double lo = a->lo + b->lo;
    fesetround(FE_UPWARD);
    double hi = a->hi + b->hi;
    fesetround(FE_TONEAREST);
    return iv_alloc(lo, hi);
}

// Subtraction: [a,b] - [c,d] = [a-d (round down), b-c (round up)]
long long nuc_interval_sub(long long h1, long long h2) {
    Interval *a = iv_get(h1), *b = iv_get(h2);
    if (!a || !b) return iv_alloc(0, 0);
    fesetround(FE_DOWNWARD);
    double lo = a->lo - b->hi;
    fesetround(FE_UPWARD);
    double hi = a->hi - b->lo;
    fesetround(FE_TONEAREST);
    return iv_alloc(lo, hi);
}

// Multiplication: [a,b] * [c,d] = [min(ac,ad,bc,bd), max(ac,ad,bc,bd)]
long long nuc_interval_mul(long long h1, long long h2) {
    Interval *a = iv_get(h1), *b = iv_get(h2);
    if (!a || !b) return iv_alloc(0, 0);

    fesetround(FE_DOWNWARD);
    double p1 = a->lo * b->lo, p2 = a->lo * b->hi;
    double p3 = a->hi * b->lo, p4 = a->hi * b->hi;
    double lo = dmin4(p1, p2, p3, p4);

    fesetround(FE_UPWARD);
    p1 = a->lo * b->lo; p2 = a->lo * b->hi;
    p3 = a->hi * b->lo; p4 = a->hi * b->hi;
    double hi = dmax4(p1, p2, p3, p4);

    fesetround(FE_TONEAREST);
    return iv_alloc(lo, hi);
}

// Division: [a,b] / [c,d] = [a,b] * [1/d, 1/c], requires 0 ∉ [c,d]
long long nuc_interval_div(long long h1, long long h2) {
    Interval *a = iv_get(h1), *b = iv_get(h2);
    if (!a || !b) return iv_alloc(-INFINITY, INFINITY);
    if (b->lo <= 0.0 && b->hi >= 0.0) {
        // Division by interval containing zero — return [-inf, +inf]
        return iv_alloc(-INFINITY, INFINITY);
    }
    // Reciprocal of [c,d]: [1/d, 1/c] with directed rounding
    fesetround(FE_DOWNWARD);
    double rlo = 1.0 / b->hi;
    fesetround(FE_UPWARD);
    double rhi = 1.0 / b->lo;
    fesetround(FE_TONEAREST);

    long long recip = iv_alloc(rlo, rhi);
    return nuc_interval_mul(h1, recip);
}

// Negation: -[a,b] = [-b, -a]
long long nuc_interval_neg(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return iv_alloc(0, 0);
    return iv_alloc(-iv->hi, -iv->lo);
}

// Absolute value: |[a,b]|
long long nuc_interval_abs(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return iv_alloc(0, 0);
    if (iv->lo >= 0) return iv_alloc(iv->lo, iv->hi);
    if (iv->hi <= 0) return iv_alloc(-iv->hi, -iv->lo);
    // Interval spans zero: [0, max(|lo|, |hi|)]
    double m = (-iv->lo > iv->hi) ? -iv->lo : iv->hi;
    return iv_alloc(0.0, m);
}

// Square root: sqrt([a,b]) = [sqrt(a) round down, sqrt(b) round up], requires a >= 0
long long nuc_interval_sqrt(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv || iv->lo < 0) return iv_alloc(0, INFINITY);
    fesetround(FE_DOWNWARD);
    double lo = sqrt(iv->lo);
    fesetround(FE_UPWARD);
    double hi = sqrt(iv->hi);
    fesetround(FE_TONEAREST);
    return iv_alloc(lo, hi);
}

// Exponential: exp([a,b]) = [exp(a) round down, exp(b) round up]
long long nuc_interval_exp(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return iv_alloc(1, 1);
    fesetround(FE_DOWNWARD);
    double lo = exp(iv->lo);
    fesetround(FE_UPWARD);
    double hi = exp(iv->hi);
    fesetround(FE_TONEAREST);
    return iv_alloc(lo, hi);
}

// Natural log: log([a,b]) = [log(a) round down, log(b) round up], requires a > 0
long long nuc_interval_log(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv || iv->lo <= 0) return iv_alloc(-INFINITY, INFINITY);
    fesetround(FE_DOWNWARD);
    double lo = log(iv->lo);
    fesetround(FE_UPWARD);
    double hi = log(iv->hi);
    fesetround(FE_TONEAREST);
    return iv_alloc(lo, hi);
}

// Integer power: [a,b]^n
long long nuc_interval_pow_int(long long handle, long long n_val) {
    Interval *iv = iv_get(handle);
    if (!iv) return iv_alloc(0, 0);
    int n = (int)n_val;
    if (n == 0) return iv_alloc(1.0, 1.0);
    if (n == 1) return iv_alloc(iv->lo, iv->hi);

    long long result = iv_alloc(1.0, 1.0);
    long long base = iv_alloc(iv->lo, iv->hi);
    int nn = (n < 0) ? -n : n;
    for (int i = 0; i < nn; i++) {
        result = nuc_interval_mul(result, base);
    }
    if (n < 0) {
        result = nuc_interval_div(iv_alloc(1.0, 1.0), result);
    }
    return result;
}

// Sine: sin([a,b]) — careful monotonicity tracking
long long nuc_interval_sin(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return iv_alloc(-1, 1);

    double a = iv->lo, b = iv->hi;
    if (b - a >= 2.0 * M_PI) return iv_alloc(-1.0, 1.0);

    // Evaluate at endpoints
    double sa = sin(a), sb = sin(b);
    double lo = (sa < sb) ? sa : sb;
    double hi = (sa > sb) ? sa : sb;

    // Check for extrema within [a,b]
    // sin has max at pi/2 + 2*k*pi and min at -pi/2 + 2*k*pi
    double two_pi = 2.0 * M_PI;
    // Check if pi/2 + 2*k*pi is in [a,b] for some integer k
    double k_max_lo = floor((a - M_PI/2.0) / two_pi);
    double k_max_hi = ceil((b - M_PI/2.0) / two_pi);
    for (double k = k_max_lo; k <= k_max_hi; k += 1.0) {
        double x = M_PI/2.0 + k * two_pi;
        if (x >= a && x <= b) { hi = 1.0; break; }
    }
    // Check for min (-pi/2 + 2*k*pi)
    double k_min_lo = floor((a + M_PI/2.0) / two_pi);
    double k_min_hi = ceil((b + M_PI/2.0) / two_pi);
    for (double k = k_min_lo; k <= k_min_hi; k += 1.0) {
        double x = -M_PI/2.0 + k * two_pi;
        if (x >= a && x <= b) { lo = -1.0; break; }
    }

    // R09-D2 Phase 1 (v0.8.277): rigorous outward rounding via
    // `nextafter`. Pre-v0.8.277 used `lo - DBL_EPSILON, hi + DBL_EPSILON`,
    // but DBL_EPSILON is the spacing at 1.0 — actual ULP near `lo`
    // grows with |lo| (at lo=1e10 the gap is ~2e-6, much wider than
    // DBL_EPSILON=2.22e-16). For |lo| >= ~1.0 the old widening was
    // narrower than 1 ULP, breaking the containment guarantee.
    // `nextafter(x, ±INF)` widens by EXACTLY 1 ULP at x's
    // magnitude — the canonical interval-arithmetic outward
    // rounding. Clamp output range to [-1, 1] since sin can't
    // exceed those.
    double widened_lo = nextafter(lo, -INFINITY);
    double widened_hi = nextafter(hi, INFINITY);
    if (widened_lo < -1.0) widened_lo = -1.0;
    if (widened_hi > 1.0)  widened_hi = 1.0;
    return iv_alloc(widened_lo, widened_hi);
}

// Cosine: cos([a,b]) = sin([a + pi/2, b + pi/2])
long long nuc_interval_cos(long long handle) {
    Interval *iv = iv_get(handle);
    if (!iv) return iv_alloc(-1, 1);
    long long shifted = iv_alloc(iv->lo + M_PI/2.0, iv->hi + M_PI/2.0);
    return nuc_interval_sin(shifted);
}

// Max of two intervals: [max(a.lo, b.lo), max(a.hi, b.hi)]
long long nuc_interval_max(long long h1, long long h2) {
    Interval *a = iv_get(h1), *b = iv_get(h2);
    if (!a || !b) return iv_alloc(0, 0);
    double lo = (a->lo > b->lo) ? a->lo : b->lo;
    double hi = (a->hi > b->hi) ? a->hi : b->hi;
    return iv_alloc(lo, hi);
}

// Min of two intervals
long long nuc_interval_min(long long h1, long long h2) {
    Interval *a = iv_get(h1), *b = iv_get(h2);
    if (!a || !b) return iv_alloc(0, 0);
    double lo = (a->lo < b->lo) ? a->lo : b->lo;
    double hi = (a->hi < b->hi) ? a->hi : b->hi;
    return iv_alloc(lo, hi);
}

// ================================================================
//  Interval Vector Operations
// ================================================================

// Interval vector: NVec of interval handles
long long nuc_ivec_new(long long n) {
    NVec *v = nvec_new();
    for (int i = 0; i < (int)n; i++) nvec_push(v, iv_alloc(0, 0));
    return (long long)(size_t)v;
}

void nuc_ivec_set(long long vec_h, long long idx, long long iv_h) {
    NVec *v = (NVec *)(size_t)vec_h;
    if (!v || idx < 0 || idx >= v->len) return;
    v->data[(int)idx] = iv_h;
}

long long nuc_ivec_get(long long vec_h, long long idx) {
    NVec *v = (NVec *)(size_t)vec_h;
    if (!v || idx < 0 || idx >= v->len) return iv_alloc(0, 0);
    return v->data[(int)idx];
}

long long nuc_ivec_len(long long vec_h) {
    NVec *v = (NVec *)(size_t)vec_h;
    return v ? v->len : 0;
}

// Element-wise addition
long long nuc_ivec_add(long long h1, long long h2) {
    NVec *a = (NVec *)(size_t)h1, *b = (NVec *)(size_t)h2;
    if (!a || !b) return 0;
    int n = a->len < b->len ? a->len : b->len;
    NVec *result = nvec_new();
    for (int i = 0; i < n; i++) {
        nvec_push(result, nuc_interval_add(a->data[i], b->data[i]));
    }
    return (long long)(size_t)result;
}

// Scalar-interval multiplication of vector
long long nuc_ivec_scale(long long vec_h, long long scalar_h) {
    NVec *v = (NVec *)(size_t)vec_h;
    if (!v) return 0;
    NVec *result = nvec_new();
    for (int i = 0; i < v->len; i++) {
        nvec_push(result, nuc_interval_mul(v->data[i], scalar_h));
    }
    return (long long)(size_t)result;
}

// Dot product: sum of element-wise products
long long nuc_ivec_dot(long long h1, long long h2) {
    NVec *a = (NVec *)(size_t)h1, *b = (NVec *)(size_t)h2;
    if (!a || !b) return iv_alloc(0, 0);
    int n = a->len < b->len ? a->len : b->len;
    long long sum = iv_alloc(0, 0);
    for (int i = 0; i < n; i++) {
        sum = nuc_interval_add(sum, nuc_interval_mul(a->data[i], b->data[i]));
    }
    return sum;
}

// L-infinity norm: max of |components|
long long nuc_ivec_linf_norm(long long vec_h) {
    NVec *v = (NVec *)(size_t)vec_h;
    if (!v || v->len == 0) return iv_alloc(0, 0);
    long long result = nuc_interval_abs(v->data[0]);
    for (int i = 1; i < v->len; i++) {
        long long comp = nuc_interval_abs(v->data[i]);
        result = nuc_interval_max(result, comp);
    }
    return result;
}

// L2 norm squared: sum of |components|^2
long long nuc_ivec_l2_norm_sq(long long vec_h) {
    NVec *v = (NVec *)(size_t)vec_h;
    if (!v) return iv_alloc(0, 0);
    long long sum = iv_alloc(0, 0);
    for (int i = 0; i < v->len; i++) {
        sum = nuc_interval_add(sum, nuc_interval_mul(v->data[i], v->data[i]));
    }
    return sum;
}

// L2 norm: sqrt(sum of squares)
long long nuc_ivec_l2_norm(long long vec_h) {
    return nuc_interval_sqrt(nuc_ivec_l2_norm_sq(vec_h));
}
