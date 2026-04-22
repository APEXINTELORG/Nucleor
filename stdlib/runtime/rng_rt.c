// rng_rt.c — Random Number Generation for Nucleor
// xoshiro256** PRNG with distributions: uniform, normal, exponential, Poisson, etc.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/rng_rt.c -o target/rng_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _rn_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _rn_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } RNVec;

// ================================================================
//  xoshiro256** state
// ================================================================

static unsigned long long rng_s[4] = {
    0x180EC6D33CFD0ABA, 0xD5A61266F0C9392C,
    0xA9582618E03FC9AA, 0x39ABDC4529B1661C
};

static unsigned long long rotl(unsigned long long x, int k) {
    return (x << k) | (x >> (64 - k));
}

static unsigned long long rng_next(void) {
    unsigned long long result = rotl(rng_s[1] * 5, 7) * 9;
    unsigned long long t = rng_s[1] << 17;
    rng_s[2] ^= rng_s[0];
    rng_s[3] ^= rng_s[1];
    rng_s[1] ^= rng_s[2];
    rng_s[0] ^= rng_s[3];
    rng_s[2] ^= t;
    rng_s[3] = rotl(rng_s[3], 45);
    return result;
}

// ================================================================
//  Seeding
// ================================================================

void nuc_rng_seed(long long seed) {
    // SplitMix64 to initialize state from single seed
    unsigned long long z = (unsigned long long)seed;
    for (int i = 0; i < 4; i++) {
        z += 0x9E3779B97F4A7C15;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
        rng_s[i] = z ^ (z >> 31);
    }
}

// ================================================================
//  State save/restore for reproducibility
// ================================================================

long long nuc_rng_state_save(void) {
    unsigned long long *buf = (unsigned long long *)malloc(4 * sizeof(unsigned long long));
    memcpy(buf, rng_s, 4 * sizeof(unsigned long long));
    return (long long)buf;
}

void nuc_rng_state_restore(long long handle) {
    unsigned long long *buf = (unsigned long long *)(void *)handle;
    if (buf) memcpy(rng_s, buf, 4 * sizeof(unsigned long long));
}

void nuc_rng_state_free(long long handle) {
    free((void *)handle);
}

// ================================================================
//  Uniform [0, 1)
// ================================================================

long long nuc_rng_uniform(void) {
    unsigned long long x = rng_next();
    double u = (double)(x >> 11) * 0x1.0p-53;  // [0, 1)
    return _rn_f2i(u);
}

// ================================================================
//  Uniform integer [lo, hi] inclusive
// ================================================================

long long nuc_rng_int(long long lo, long long hi) {
    if (hi <= lo) return lo;
    unsigned long long range = (unsigned long long)(hi - lo + 1);
    unsigned long long x = rng_next();
    return lo + (long long)(x % range);
}

// ================================================================
//  Normal distribution N(0,1) via Box-Muller
// ================================================================

static int _rn_has_spare = 0;
static double _rn_spare = 0;

long long nuc_rng_normal(void) {
    if (_rn_has_spare) {
        _rn_has_spare = 0;
        return _rn_f2i(_rn_spare);
    }
    double u, v, s;
    do {
        u = (double)(rng_next() >> 11) * 0x1.0p-53 * 2.0 - 1.0;
        v = (double)(rng_next() >> 11) * 0x1.0p-53 * 2.0 - 1.0;
        s = u * u + v * v;
    } while (s >= 1.0 || s == 0.0);
    double mul = sqrt(-2.0 * log(s) / s);
    _rn_spare = v * mul;
    _rn_has_spare = 1;
    return _rn_f2i(u * mul);
}

// ================================================================
//  Exponential distribution with rate lambda
// ================================================================

long long nuc_rng_exponential(long long lambda_bits) {
    double lam = _rn_i2f(lambda_bits);
    if (lam <= 0) lam = 1.0;
    double u = (double)(rng_next() >> 11) * 0x1.0p-53;
    if (u == 0.0) u = 1e-15;
    return _rn_f2i(-log(u) / lam);
}

// ================================================================
//  Poisson distribution with rate lambda
// ================================================================

long long nuc_rng_poisson(long long lambda_bits) {
    double lam = _rn_i2f(lambda_bits);
    double L = exp(-lam);
    long long k = 0;
    double p = 1.0;
    do {
        k++;
        double u = (double)(rng_next() >> 11) * 0x1.0p-53;
        p *= u;
    } while (p > L);
    return k - 1;
}

// ================================================================
//  Bernoulli trial: returns 0 or 1
// ================================================================

long long nuc_rng_bernoulli(long long p_bits) {
    double p = _rn_i2f(p_bits);
    double u = (double)(rng_next() >> 11) * 0x1.0p-53;
    return u < p ? 1 : 0;
}

// ================================================================
//  Sample n elements from a Vec (without replacement)
// ================================================================

long long nuc_rng_choice(long long vec_handle, long long n) {
    RNVec *v = (RNVec *)(void *)vec_handle;
    if (!v || v->len == 0) return 0;
    int m = (int)n;
    if (m > v->len) m = v->len;

    // Fisher-Yates partial shuffle on a copy of indices
    int *idx = (int *)malloc(v->len * sizeof(int));
    for (int i = 0; i < v->len; i++) idx[i] = i;
    for (int i = 0; i < m; i++) {
        int j = i + (int)(rng_next() % (unsigned long long)(v->len - i));
        int tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp;
    }

    RNVec *out = (RNVec *)malloc(sizeof(RNVec));
    out->cap = m; out->len = m;
    out->data = (long long *)malloc(m * sizeof(long long));
    for (int i = 0; i < m; i++) out->data[i] = v->data[idx[i]];

    free(idx);
    return (long long)out;
}

// ================================================================
//  Shuffle Vec in-place
// ================================================================

void nuc_rng_shuffle(long long vec_handle) {
    RNVec *v = (RNVec *)(void *)vec_handle;
    if (!v || v->len <= 1) return;
    for (int i = v->len - 1; i > 0; i--) {
        int j = (int)(rng_next() % (unsigned long long)(i + 1));
        long long tmp = v->data[i]; v->data[i] = v->data[j]; v->data[j] = tmp;
    }
}

// ================================================================
//  Uniform f64 in range [lo, hi)
// ================================================================

long long nuc_rng_uniform_range(long long lo_bits, long long hi_bits) {
    double lo = _rn_i2f(lo_bits), hi = _rn_i2f(hi_bits);
    double u = (double)(rng_next() >> 11) * 0x1.0p-53;
    return _rn_f2i(lo + u * (hi - lo));
}

// ================================================================
//  Fill Vec with N random uniform [0,1) values
// ================================================================

long long nuc_rng_uniform_vec(long long n) {
    int m = (int)n;
    RNVec *out = (RNVec *)malloc(sizeof(RNVec));
    out->cap = m; out->len = m;
    out->data = (long long *)malloc(m * sizeof(long long));
    for (int i = 0; i < m; i++) {
        double u = (double)(rng_next() >> 11) * 0x1.0p-53;
        out->data[i] = _rn_f2i(u);
    }
    return (long long)out;
}

// ================================================================
//  Fill Vec with N random normal N(0,1) values
// ================================================================

long long nuc_rng_normal_vec(long long n) {
    int m = (int)n;
    RNVec *out = (RNVec *)malloc(sizeof(RNVec));
    out->cap = m; out->len = m;
    out->data = (long long *)malloc(m * sizeof(long long));
    for (int i = 0; i < m; i++) {
        out->data[i] = nuc_rng_normal();
    }
    return (long long)out;
}
