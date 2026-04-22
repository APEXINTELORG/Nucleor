// bspline_rt.c — B-Spline Evaluation for Nucleor
// De Boor's algorithm, knot vectors, derivatives, fitting. Enables KANs.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/bspline_rt.c -o target/bspline_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _bs_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _bs_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } BSVec;

// ================================================================
//  B-Spline Basis Function (Cox-de Boor recursion)
//  knots: knot vector [n+k+1], order k (degree k-1)
//  N_{i,k}(x) evaluated at x for basis i
// ================================================================

static double bspline_basis(double *knots, int i, int k, double x) {
    if (k == 1) {
        return (x >= knots[i] && x < knots[i + 1]) ? 1.0 : 0.0;
    }
    double left = 0, right = 0;
    double d1 = knots[i + k - 1] - knots[i];
    double d2 = knots[i + k] - knots[i + 1];
    if (d1 > 1e-15) left = (x - knots[i]) / d1 * bspline_basis(knots, i, k - 1, x);
    if (d2 > 1e-15) right = (knots[i + k] - x) / d2 * bspline_basis(knots, i + 1, k - 1, x);
    return left + right;
}

// ================================================================
//  De Boor's Algorithm (efficient B-spline evaluation)
//  knots: [n+k+1], ctrl_pts: [n] control points, order k, eval at x
// ================================================================

long long nuc_bspline_eval(long long knots_h, long long ctrl_h, long long order, long long x_bits) {
    BSVec *knots_v = (BSVec *)(void *)knots_h;
    BSVec *ctrl_v = (BSVec *)(void *)ctrl_h;
    int k = (int)order;
    double x = _bs_i2f(x_bits);
    int n = ctrl_v->len;
    int n_knots = knots_v->len;

    double *knots = (double *)malloc(n_knots * sizeof(double));
    for (int i = 0; i < n_knots; i++) knots[i] = _bs_i2f(knots_v->data[i]);

    // Find span: knots[s] <= x < knots[s+1]
    int s = k - 1;
    for (int i = k - 1; i < n; i++) {
        if (x >= knots[i] && x < knots[i + 1]) { s = i; break; }
    }
    // Handle right endpoint
    if (x >= knots[n]) s = n - 1;

    // De Boor's algorithm
    double *d = (double *)malloc(k * sizeof(double));
    for (int j = 0; j < k; j++) {
        int idx = s - k + 1 + j;
        if (idx >= 0 && idx < n) d[j] = _bs_i2f(ctrl_v->data[idx]);
        else d[j] = 0;
    }

    for (int r = 1; r < k; r++) {
        for (int j = k - 1; j >= r; j--) {
            int i_idx = s - k + 1 + j;
            double denom = knots[i_idx + k - r] - knots[i_idx];
            double alpha = (denom > 1e-15) ? (x - knots[i_idx]) / denom : 0;
            d[j] = (1 - alpha) * d[j - 1] + alpha * d[j];
        }
    }

    double result = d[k - 1];
    free(knots); free(d);
    return _bs_f2i(result);
}

// ================================================================
//  Evaluate all basis functions at x (for KAN layers)
//  Returns Vec of n basis values
// ================================================================

long long nuc_bspline_basis_all(long long knots_h, long long n_basis, long long order, long long x_bits) {
    BSVec *knots_v = (BSVec *)(void *)knots_h;
    int nb = (int)n_basis, k = (int)order;
    double x = _bs_i2f(x_bits);
    int n_knots = knots_v->len;

    double *knots = (double *)malloc(n_knots * sizeof(double));
    for (int i = 0; i < n_knots; i++) knots[i] = _bs_i2f(knots_v->data[i]);

    BSVec *out = (BSVec *)malloc(sizeof(BSVec));
    out->len = nb; out->cap = nb;
    out->data = (long long *)malloc(nb * sizeof(long long));

    for (int i = 0; i < nb; i++)
        out->data[i] = _bs_f2i(bspline_basis(knots, i, k, x));

    free(knots);
    return (long long)out;
}

// ================================================================
//  B-Spline Derivative (order k-1 with modified control points)
// ================================================================

long long nuc_bspline_deriv(long long knots_h, long long ctrl_h, long long order, long long x_bits) {
    BSVec *knots_v = (BSVec *)(void *)knots_h;
    BSVec *ctrl_v = (BSVec *)(void *)ctrl_h;
    int k = (int)order;
    double x = _bs_i2f(x_bits);
    int n = ctrl_v->len;
    int n_knots = knots_v->len;

    double *knots = (double *)malloc(n_knots * sizeof(double));
    for (int i = 0; i < n_knots; i++) knots[i] = _bs_i2f(knots_v->data[i]);

    // Derivative control points: d'_i = (k-1) * (c_{i+1} - c_i) / (t_{i+k} - t_{i+1})
    int nd = n - 1;
    double *dctrl = (double *)malloc(nd * sizeof(double));
    for (int i = 0; i < nd; i++) {
        double denom = knots[i + k] - knots[i + 1];
        double ci = _bs_i2f(ctrl_v->data[i]);
        double ci1 = _bs_i2f(ctrl_v->data[i + 1]);
        dctrl[i] = (denom > 1e-15) ? (k - 1) * (ci1 - ci) / denom : 0;
    }

    // Evaluate derivative spline (order k-1)
    BSVec *dctrl_v = (BSVec *)malloc(sizeof(BSVec));
    dctrl_v->len = nd; dctrl_v->cap = nd;
    dctrl_v->data = (long long *)malloc(nd * sizeof(long long));
    for (int i = 0; i < nd; i++) dctrl_v->data[i] = _bs_f2i(dctrl[i]);

    long long result = nuc_bspline_eval(knots_h, (long long)dctrl_v, k - 1, x_bits);
    free(knots); free(dctrl);
    return result;
}

// ================================================================
//  Generate uniform knot vector for n basis functions of order k
// ================================================================

long long nuc_bspline_uniform_knots(long long n_basis, long long order,
                                      long long lo_bits, long long hi_bits) {
    int nb = (int)n_basis, k = (int)order;
    double lo = _bs_i2f(lo_bits), hi = _bs_i2f(hi_bits);
    int n_knots = nb + k;

    BSVec *knots = (BSVec *)malloc(sizeof(BSVec));
    knots->len = n_knots; knots->cap = n_knots;
    knots->data = (long long *)malloc(n_knots * sizeof(long long));

    // Clamped uniform knots
    for (int i = 0; i < k; i++) knots->data[i] = _bs_f2i(lo);
    int n_internal = n_knots - 2 * k;
    for (int i = 0; i < n_internal; i++) {
        double t = lo + (hi - lo) * (i + 1.0) / (n_internal + 1.0);
        knots->data[k + i] = _bs_f2i(t);
    }
    for (int i = 0; i < k; i++) knots->data[n_knots - k + i] = _bs_f2i(hi);

    return (long long)knots;
}

// ================================================================
//  KAN Layer Forward: sum of B-spline basis functions * learnable weights
//  For each input dimension, evaluate B-spline, multiply by edge weights
//  inputs: [batch, in_dim], weights: [out_dim, in_dim, n_basis]
//  Returns: [batch, out_dim]
// ================================================================

long long nuc_bspline_kan_forward(long long inputs_h, long long weights_h, long long knots_h,
                                    long long batch, long long in_dim, long long out_dim,
                                    long long n_basis, long long order) {
    BSVec *inputs = (BSVec *)(void *)inputs_h;
    BSVec *weights = (BSVec *)(void *)weights_h;
    int B = (int)batch, id = (int)in_dim, od = (int)out_dim, nb = (int)n_basis;

    BSVec *output = (BSVec *)malloc(sizeof(BSVec));
    output->len = B * od; output->cap = output->len;
    output->data = (long long *)calloc(output->len, sizeof(long long));

    for (int b = 0; b < B; b++) {
        for (int o = 0; o < od; o++) {
            double sum = 0;
            for (int i = 0; i < id; i++) {
                double x = _bs_i2f(inputs->data[b * id + i]);
                // Evaluate all basis functions at x
                long long basis_h = nuc_bspline_basis_all(knots_h, n_basis, order, _bs_f2i(x));
                BSVec *basis = (BSVec *)(void *)basis_h;
                // Weighted sum
                for (int j = 0; j < nb; j++) {
                    double w = _bs_i2f(weights->data[o * id * nb + i * nb + j]);
                    sum += w * _bs_i2f(basis->data[j]);
                }
            }
            output->data[b * od + o] = _bs_f2i(sum);
        }
    }
    return (long long)output;
}
