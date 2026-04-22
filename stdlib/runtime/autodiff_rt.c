// autodiff_rt.c — Reverse-Mode Automatic Differentiation for Nucleor
// Tape-based computation graph with backpropagation.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/autodiff_rt.c -o target/autodiff_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ad_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ad_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Tape Node
// ================================================================

#define AD_CONST  0
#define AD_VAR    1
#define AD_ADD    2
#define AD_SUB    3
#define AD_MUL    4
#define AD_DIV    5
#define AD_SIN    6
#define AD_COS    7
#define AD_EXP    8
#define AD_LOG    9
#define AD_POW   10
#define AD_SQRT  11
#define AD_NEG   12
#define AD_ABS   13
#define AD_TANH  14

typedef struct {
    int op;
    int left, right;   // parent node indices (-1 if none)
    double val;
    double grad;
    double aux;        // for POW: exponent
} ADNode;

#define AD_MAX_NODES 500000
static ADNode ad_tape[AD_MAX_NODES];
static int ad_next = 0;

static int ad_alloc(int op, int left, int right, double val) {
    if (ad_next >= AD_MAX_NODES) ad_next = 0; // emergency wrap
    int idx = ad_next++;
    ad_tape[idx].op = op;
    ad_tape[idx].left = left;
    ad_tape[idx].right = right;
    ad_tape[idx].val = val;
    ad_tape[idx].grad = 0.0;
    ad_tape[idx].aux = 0.0;
    return idx;
}

// ================================================================
//  Public API: Create nodes
// ================================================================

long long nuc_ad_var(long long val_bits) {
    double v = _ad_i2f(val_bits);
    return (long long)ad_alloc(AD_VAR, -1, -1, v);
}

long long nuc_ad_const(long long val_bits) {
    double v = _ad_i2f(val_bits);
    return (long long)ad_alloc(AD_CONST, -1, -1, v);
}

// ================================================================
//  Arithmetic operations
// ================================================================

long long nuc_ad_add(long long a, long long b) {
    int ai = (int)a, bi = (int)b;
    return (long long)ad_alloc(AD_ADD, ai, bi, ad_tape[ai].val + ad_tape[bi].val);
}

long long nuc_ad_sub(long long a, long long b) {
    int ai = (int)a, bi = (int)b;
    return (long long)ad_alloc(AD_SUB, ai, bi, ad_tape[ai].val - ad_tape[bi].val);
}

long long nuc_ad_mul(long long a, long long b) {
    int ai = (int)a, bi = (int)b;
    return (long long)ad_alloc(AD_MUL, ai, bi, ad_tape[ai].val * ad_tape[bi].val);
}

long long nuc_ad_div(long long a, long long b) {
    int ai = (int)a, bi = (int)b;
    double bv = ad_tape[bi].val;
    double v = (fabs(bv) > 1e-30) ? ad_tape[ai].val / bv : 0.0;
    return (long long)ad_alloc(AD_DIV, ai, bi, v);
}

long long nuc_ad_neg(long long a) {
    int ai = (int)a;
    return (long long)ad_alloc(AD_NEG, ai, -1, -ad_tape[ai].val);
}

// ================================================================
//  Transcendental functions
// ================================================================

long long nuc_ad_sin(long long a) {
    int ai = (int)a;
    return (long long)ad_alloc(AD_SIN, ai, -1, sin(ad_tape[ai].val));
}

long long nuc_ad_cos(long long a) {
    int ai = (int)a;
    return (long long)ad_alloc(AD_COS, ai, -1, cos(ad_tape[ai].val));
}

long long nuc_ad_exp(long long a) {
    int ai = (int)a;
    return (long long)ad_alloc(AD_EXP, ai, -1, exp(ad_tape[ai].val));
}

long long nuc_ad_log(long long a) {
    int ai = (int)a;
    double av = ad_tape[ai].val;
    return (long long)ad_alloc(AD_LOG, ai, -1, (av > 0) ? log(av) : -1e30);
}

long long nuc_ad_sqrt(long long a) {
    int ai = (int)a;
    double av = ad_tape[ai].val;
    return (long long)ad_alloc(AD_SQRT, ai, -1, (av >= 0) ? sqrt(av) : 0.0);
}

long long nuc_ad_pow(long long a, long long n_bits) {
    int ai = (int)a;
    double n = _ad_i2f(n_bits);
    int idx = ad_alloc(AD_POW, ai, -1, pow(ad_tape[ai].val, n));
    ad_tape[idx].aux = n;
    return (long long)idx;
}

long long nuc_ad_abs(long long a) {
    int ai = (int)a;
    return (long long)ad_alloc(AD_ABS, ai, -1, fabs(ad_tape[ai].val));
}

long long nuc_ad_tanh(long long a) {
    int ai = (int)a;
    return (long long)ad_alloc(AD_TANH, ai, -1, tanh(ad_tape[ai].val));
}

// ================================================================
//  Value access
// ================================================================

long long nuc_ad_value(long long h) {
    int idx = (int)h;
    return _ad_f2i(ad_tape[idx].val);
}

// ================================================================
//  Reverse-mode gradient computation
// ================================================================

long long nuc_ad_grad(long long h, long long var) {
    int output = (int)h;
    int var_idx = (int)var;

    // Clear all gradients
    for (int i = 0; i <= output; i++) ad_tape[i].grad = 0.0;
    ad_tape[output].grad = 1.0;

    // Backward pass (reverse topological order = reverse allocation order)
    for (int i = output; i >= 0; i--) {
        double g = ad_tape[i].grad;
        if (g == 0.0) continue;
        int L = ad_tape[i].left, R = ad_tape[i].right;

        switch (ad_tape[i].op) {
            case AD_ADD:
                ad_tape[L].grad += g;
                ad_tape[R].grad += g;
                break;
            case AD_SUB:
                ad_tape[L].grad += g;
                ad_tape[R].grad -= g;
                break;
            case AD_MUL:
                ad_tape[L].grad += g * ad_tape[R].val;
                ad_tape[R].grad += g * ad_tape[L].val;
                break;
            case AD_DIV:
                if (fabs(ad_tape[R].val) > 1e-30) {
                    ad_tape[L].grad += g / ad_tape[R].val;
                    ad_tape[R].grad -= g * ad_tape[L].val / (ad_tape[R].val * ad_tape[R].val);
                }
                break;
            case AD_NEG:
                ad_tape[L].grad -= g;
                break;
            case AD_SIN:
                ad_tape[L].grad += g * cos(ad_tape[L].val);
                break;
            case AD_COS:
                ad_tape[L].grad -= g * sin(ad_tape[L].val);
                break;
            case AD_EXP:
                ad_tape[L].grad += g * ad_tape[i].val; // exp(x) * g
                break;
            case AD_LOG:
                if (fabs(ad_tape[L].val) > 1e-30)
                    ad_tape[L].grad += g / ad_tape[L].val;
                break;
            case AD_SQRT:
                if (ad_tape[i].val > 1e-30)
                    ad_tape[L].grad += g * 0.5 / ad_tape[i].val;
                break;
            case AD_POW: {
                double n = ad_tape[i].aux;
                ad_tape[L].grad += g * n * pow(ad_tape[L].val, n - 1);
                break;
            }
            case AD_ABS:
                ad_tape[L].grad += g * (ad_tape[L].val >= 0 ? 1.0 : -1.0);
                break;
            case AD_TANH: {
                double tv = ad_tape[i].val;
                ad_tape[L].grad += g * (1.0 - tv * tv);
                break;
            }
        }
    }

    return _ad_f2i(ad_tape[var_idx].grad);
}

// ================================================================
//  Reset computation graph
// ================================================================

void nuc_ad_reset(void) {
    ad_next = 0;
}

// ================================================================
//  Checkpoint (for partial resets)
// ================================================================

long long nuc_ad_checkpoint(void) {
    return (long long)ad_next;
}

void nuc_ad_restore(long long checkpoint) {
    ad_next = (int)checkpoint;
}
