// quad_rt.c — Numerical Integration (Quadrature) for Nucleor
// Trapezoid, Simpson, Gauss-Legendre, adaptive Simpson, 2D, Monte Carlo.
// Uses function-pointer callbacks.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/quad_rt.c -o target/quad_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _qu_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _qu_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Trapezoid Rule
// ================================================================

long long nuc_quad_trapezoid(long long f_ptr, long long a_bits, long long b_bits, long long n) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double a = _qu_i2f(a_bits), b = _qu_i2f(b_bits);
    int N = (int)n;
    double h = (b - a) / N;

    double sum = 0.5 * (_qu_i2f(f(_qu_f2i(a))) + _qu_i2f(f(_qu_f2i(b))));
    for (int i = 1; i < N; i++)
        sum += _qu_i2f(f(_qu_f2i(a + i * h)));
    return _qu_f2i(sum * h);
}

// ================================================================
//  Simpson's Rule
// ================================================================

long long nuc_quad_simpson(long long f_ptr, long long a_bits, long long b_bits, long long n) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double a = _qu_i2f(a_bits), b = _qu_i2f(b_bits);
    int N = (int)n;
    if (N % 2 != 0) N++;
    double h = (b - a) / N;

    double sum = _qu_i2f(f(_qu_f2i(a))) + _qu_i2f(f(_qu_f2i(b)));
    for (int i = 1; i < N; i++) {
        double x = a + i * h;
        double fx = _qu_i2f(f(_qu_f2i(x)));
        sum += (i % 2 == 0) ? 2 * fx : 4 * fx;
    }
    return _qu_f2i(sum * h / 3.0);
}

// ================================================================
//  Gauss-Legendre (5-point)
// ================================================================

long long nuc_quad_gauss(long long f_ptr, long long a_bits, long long b_bits, long long n) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double a = _qu_i2f(a_bits), b = _qu_i2f(b_bits);
    int N = (int)n;

    // 5-point Gauss-Legendre nodes and weights on [-1, 1]
    static const double nodes[] = {
        -0.9061798459386640, -0.5384693101056831, 0.0,
         0.5384693101056831,  0.9061798459386640
    };
    static const double weights[] = {
        0.2369268850561891, 0.4786286704993665, 0.5688888888888889,
        0.4786286704993665, 0.2369268850561891
    };

    double total = 0;
    double h = (b - a) / N;
    for (int seg = 0; seg < N; seg++) {
        double lo = a + seg * h, hi = lo + h;
        double mid = 0.5 * (lo + hi), half = 0.5 * (hi - lo);
        for (int k = 0; k < 5; k++) {
            double x = mid + half * nodes[k];
            total += weights[k] * _qu_i2f(f(_qu_f2i(x))) * half;
        }
    }
    return _qu_f2i(total);
}

// ================================================================
//  Adaptive Simpson
// ================================================================

static double adapt_simpson_impl(long long (*f)(long long), double a, double b,
                                  double tol, double fa, double fb, double fm, double whole, int depth) {
    double m = (a + b) * 0.5;
    double lm = (a + m) * 0.5, rm = (m + b) * 0.5;
    double flm = _qu_i2f(f(_qu_f2i(lm)));
    double frm = _qu_i2f(f(_qu_f2i(rm)));
    double h6 = (b - a) / 12.0;
    double left  = h6 * (fa + 4 * flm + fm);
    double right = h6 * (fm + 4 * frm + fb);
    double result = left + right;
    if (depth >= 30 || fabs(result - whole) < 15 * tol) {
        return result + (result - whole) / 15.0;
    }
    return adapt_simpson_impl(f, a, m, tol / 2, fa, fm, flm, left, depth + 1)
         + adapt_simpson_impl(f, m, b, tol / 2, fm, fb, frm, right, depth + 1);
}

long long nuc_quad_adaptive(long long f_ptr, long long a_bits, long long b_bits, long long tol_bits) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double a = _qu_i2f(a_bits), b = _qu_i2f(b_bits), tol = _qu_i2f(tol_bits);
    double fa = _qu_i2f(f(_qu_f2i(a)));
    double fb = _qu_i2f(f(_qu_f2i(b)));
    double m = (a + b) * 0.5;
    double fm = _qu_i2f(f(_qu_f2i(m)));
    double whole = (b - a) / 6.0 * (fa + 4 * fm + fb);
    return _qu_f2i(adapt_simpson_impl(f, a, b, tol, fa, fb, fm, whole, 0));
}

// ================================================================
//  2D Integration (tensor product of Simpson)
// ================================================================

long long nuc_quad_2d(long long f_ptr, long long ax_bits, long long bx_bits,
                       long long ay_bits, long long by_bits, long long n) {
    typedef long long (*Fn2D)(long long, long long);
    Fn2D f = (Fn2D)(void *)f_ptr;
    double ax = _qu_i2f(ax_bits), bx = _qu_i2f(bx_bits);
    double ay = _qu_i2f(ay_bits), by = _qu_i2f(by_bits);
    int N = (int)n;
    if (N % 2 != 0) N++;

    double hx = (bx - ax) / N, hy = (by - ay) / N;
    double total = 0;

    for (int i = 0; i <= N; i++) {
        double x = ax + i * hx;
        double wx = (i == 0 || i == N) ? 1.0 : (i % 2 == 0) ? 2.0 : 4.0;
        for (int j = 0; j <= N; j++) {
            double y = ay + j * hy;
            double wy = (j == 0 || j == N) ? 1.0 : (j % 2 == 0) ? 2.0 : 4.0;
            total += wx * wy * _qu_i2f(f(_qu_f2i(x), _qu_f2i(y)));
        }
    }
    return _qu_f2i(total * hx * hy / 9.0);
}

// ================================================================
//  Monte Carlo Integration
//  Returns integral estimate. Error estimate via second call.
// ================================================================

long long nuc_quad_monte_carlo(long long f_ptr, long long lo_h, long long hi_h, long long n) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *lo = (NVec *)(void *)lo_h, *hi = (NVec *)(void *)hi_h;
    int dim = lo->len;
    int N = (int)n;

    // Simple LCG
    unsigned int rng = 12345;
    #define QMC_RAND() (rng = rng * 1103515245 + 12345, ((double)((rng >> 16) & 0x7FFF)) / 32767.0)

    double volume = 1.0;
    for (int d = 0; d < dim; d++)
        volume *= _qu_i2f(hi->data[d]) - _qu_i2f(lo->data[d]);

    NVec *x = (NVec *)malloc(sizeof(NVec));
    x->len = dim; x->cap = dim;
    x->data = (long long *)malloc(dim * sizeof(long long));

    double sum = 0;
    for (int i = 0; i < N; i++) {
        for (int d = 0; d < dim; d++) {
            double ld = _qu_i2f(lo->data[d]), hd = _qu_i2f(hi->data[d]);
            x->data[d] = _qu_f2i(ld + QMC_RAND() * (hd - ld));
        }
        sum += _qu_i2f(f((long long)x));
    }
    #undef QMC_RAND
    return _qu_f2i(volume * sum / N);
}
