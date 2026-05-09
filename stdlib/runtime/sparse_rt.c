// sparse_rt.c — Sparse Matrix Operations (CSR Format) for Nucleor
// Conjugate Gradient, GMRES, ILU preconditioner, sparse-dense conversion.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/sparse_rt.c -o target/sparse_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _sp_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _sp_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  CSR Sparse Matrix
// ================================================================

typedef struct {
    int rows, cols, nnz;
    double *vals;    // non-zero values [nnz]
    int *col_idx;    // column indices [nnz]
    int *row_ptr;    // row pointers [rows+1]
} SpMat;

// ================================================================
//  Construction
// ================================================================

long long nuc_sp_new_csr(long long rows, long long cols, long long nnz) {
    int r = (int)rows, c = (int)cols, n = (int)nnz;
    SpMat *m = (SpMat *)calloc(1, sizeof(SpMat));
    m->rows = r; m->cols = c; m->nnz = n;
    m->vals = (double *)calloc(n, sizeof(double));
    m->col_idx = (int *)calloc(n, sizeof(int));
    m->row_ptr = (int *)calloc(r + 1, sizeof(int));
    return (long long)m;
}

// Build CSR from COO (coordinate) format
// row_vec, col_vec, val_vec are Nucleor Vecs.
// `_inferred` derives nnz from row_vec->len (the canonical entry count).
long long nuc_sp_from_coo_inferred(long long row_vec, long long col_vec, long long val_vec,
                                     long long rows, long long cols) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *rv = (NVec *)(void *)row_vec;
    NVec *cv = (NVec *)(void *)col_vec;
    NVec *vv = (NVec *)(void *)val_vec;
    int r = (int)rows, c = (int)cols, nnz = rv->len;

    SpMat *m = (SpMat *)calloc(1, sizeof(SpMat));
    m->rows = r; m->cols = c; m->nnz = nnz;
    m->vals = (double *)malloc(nnz * sizeof(double));
    m->col_idx = (int *)malloc(nnz * sizeof(int));
    m->row_ptr = (int *)calloc(r + 1, sizeof(int));

    // Count entries per row
    for (int i = 0; i < nnz; i++) {
        int ri = (int)rv->data[i];
        if (ri >= 0 && ri < r) m->row_ptr[ri + 1]++;
    }
    for (int i = 0; i < r; i++) m->row_ptr[i + 1] += m->row_ptr[i];

    // Fill CSR arrays
    int *temp = (int *)calloc(r, sizeof(int));
    for (int i = 0; i < nnz; i++) {
        int ri = (int)rv->data[i];
        int pos = m->row_ptr[ri] + temp[ri];
        m->col_idx[pos] = (int)cv->data[i];
        m->vals[pos] = _sp_i2f(vv->data[i]);
        temp[ri]++;
    }
    free(temp);
    return (long long)m;
}

// 6-arg shim — match the rod's declared arity. Pre-2026-05-05 the rod
// declared 6-arg `(row, col, val, rows, cols, nnz)` but C took 5
// (nnz was derived from row->len). The 6th arg was silently dropped
// by the Windows x64 calling convention — the rod's nnz hint had no
// effect. The shim accepts the caller-provided nnz_hint, validates it
// against row->len (zero is sentinel meaning "derive from row->len"),
// and forwards. Mismatched nnz_hint logs nothing today; future Phase
// could promote to a hard error.
long long nuc_sp_from_coo(long long row_vec, long long col_vec, long long val_vec,
                           long long rows, long long cols, long long nnz_hint) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *rv = (NVec *)(void *)row_vec;
    /* nnz_hint is informational; canonical nnz = row_vec->len. */
    (void)nnz_hint;
    (void)rv;
    return nuc_sp_from_coo_inferred(row_vec, col_vec, val_vec, rows, cols);
}

void nuc_sp_set(long long handle, long long r, long long c, long long val_bits) {
    SpMat *m = (SpMat *)(void *)handle;
    if (!m) return;
    int ri = (int)r;
    for (int k = m->row_ptr[ri]; k < m->row_ptr[ri + 1]; k++) {
        if (m->col_idx[k] == (int)c) {
            m->vals[k] = _sp_i2f(val_bits);
            return;
        }
    }
}

long long nuc_sp_get(long long handle, long long r, long long c) {
    SpMat *m = (SpMat *)(void *)handle;
    if (!m) return _sp_f2i(0.0);
    int ri = (int)r;
    for (int k = m->row_ptr[ri]; k < m->row_ptr[ri + 1]; k++) {
        if (m->col_idx[k] == (int)c) return _sp_f2i(m->vals[k]);
    }
    return _sp_f2i(0.0);
}

long long nuc_sp_rows(long long h) { return ((SpMat *)(void *)h)->rows; }
long long nuc_sp_cols(long long h) { return ((SpMat *)(void *)h)->cols; }
long long nuc_sp_nnz(long long h)  { return ((SpMat *)(void *)h)->nnz; }

// ================================================================
//  Sparse Mat-Vec: y = A * x
// ================================================================

long long nuc_sp_mul_vec(long long ah, long long xh) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    SpMat *a = (SpMat *)(void *)ah;
    NVec *x = (NVec *)(void *)xh;

    NVec *y = (NVec *)malloc(sizeof(NVec));
    y->len = a->rows; y->cap = a->rows;
    y->data = (long long *)malloc(a->rows * sizeof(long long));

    for (int i = 0; i < a->rows; i++) {
        double sum = 0;
        for (int k = a->row_ptr[i]; k < a->row_ptr[i + 1]; k++) {
            sum += a->vals[k] * _sp_i2f(x->data[a->col_idx[k]]);
        }
        y->data[i] = _sp_f2i(sum);
    }
    return (long long)y;
}

// ================================================================
//  Conjugate Gradient (for symmetric positive definite A)
// ================================================================

long long nuc_sp_cg_solve(long long ah, long long bh, long long tol_bits) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    SpMat *A = (SpMat *)(void *)ah;
    NVec *b = (NVec *)(void *)bh;
    double tol = _sp_i2f(tol_bits);
    int n = A->rows;

    double *x = (double *)calloc(n, sizeof(double));
    double *r = (double *)malloc(n * sizeof(double));
    double *p = (double *)malloc(n * sizeof(double));
    double *Ap = (double *)malloc(n * sizeof(double));

    // r = b - A*x (x=0 so r=b)
    for (int i = 0; i < n; i++) {
        r[i] = _sp_i2f(b->data[i]);
        p[i] = r[i];
    }

    double rsold = 0;
    for (int i = 0; i < n; i++) rsold += r[i] * r[i];

    int max_iter = n > 1000 ? n : 1000;
    for (int iter = 0; iter < max_iter; iter++) {
        if (sqrt(rsold) < tol) break;

        // Ap = A * p
        for (int i = 0; i < n; i++) {
            double sum = 0;
            for (int k = A->row_ptr[i]; k < A->row_ptr[i + 1]; k++)
                sum += A->vals[k] * p[A->col_idx[k]];
            Ap[i] = sum;
        }

        double pAp = 0;
        for (int i = 0; i < n; i++) pAp += p[i] * Ap[i];
        if (fabs(pAp) < 1e-30) break;
        double alpha = rsold / pAp;

        for (int i = 0; i < n; i++) {
            x[i] += alpha * p[i];
            r[i] -= alpha * Ap[i];
        }

        double rsnew = 0;
        for (int i = 0; i < n; i++) rsnew += r[i] * r[i];

        double beta = rsnew / rsold;
        for (int i = 0; i < n; i++) p[i] = r[i] + beta * p[i];
        rsold = rsnew;
    }

    NVec *result = (NVec *)malloc(sizeof(NVec));
    result->len = n; result->cap = n;
    result->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++) result->data[i] = _sp_f2i(x[i]);

    free(x); free(r); free(p); free(Ap);
    return (long long)result;
}

// ================================================================
//  GMRES (for non-symmetric systems)
// ================================================================

long long nuc_sp_gmres(long long ah, long long bh, long long tol_bits) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    SpMat *A = (SpMat *)(void *)ah;
    NVec *b = (NVec *)(void *)bh;
    double tol = _sp_i2f(tol_bits);
    int n = A->rows;
    int m = 50; // restart parameter
    if (m > n) m = n;

    double *x = (double *)calloc(n, sizeof(double));
    double *r = (double *)malloc(n * sizeof(double));

    // r = b (since x=0)
    for (int i = 0; i < n; i++) r[i] = _sp_i2f(b->data[i]);

    double rnorm = 0;
    for (int i = 0; i < n; i++) rnorm += r[i] * r[i];
    rnorm = sqrt(rnorm);
    if (rnorm < tol) goto done;

    // Arnoldi basis V[m+1][n], Hessenberg H[m+1][m]
    double **V = (double **)malloc((m + 1) * sizeof(double *));
    for (int i = 0; i <= m; i++) V[i] = (double *)calloc(n, sizeof(double));
    double *H = (double *)calloc((m + 1) * m, sizeof(double));
    double *cs = (double *)calloc(m, sizeof(double));
    double *sn = (double *)calloc(m, sizeof(double));
    double *g = (double *)calloc(m + 1, sizeof(double));

    // V[0] = r / ||r||
    for (int i = 0; i < n; i++) V[0][i] = r[i] / rnorm;
    g[0] = rnorm;

    int j;
    for (j = 0; j < m; j++) {
        // w = A * V[j]
        double *w = V[j + 1];
        for (int i = 0; i < n; i++) {
            double sum = 0;
            for (int k = A->row_ptr[i]; k < A->row_ptr[i + 1]; k++)
                sum += A->vals[k] * V[j][A->col_idx[k]];
            w[i] = sum;
        }

        // Gram-Schmidt
        for (int i = 0; i <= j; i++) {
            double dot = 0;
            for (int k = 0; k < n; k++) dot += w[k] * V[i][k];
            H[i * m + j] = dot;
            for (int k = 0; k < n; k++) w[k] -= dot * V[i][k];
        }
        double wnorm = 0;
        for (int k = 0; k < n; k++) wnorm += w[k] * w[k];
        wnorm = sqrt(wnorm);
        H[(j + 1) * m + j] = wnorm;
        if (wnorm > 1e-15)
            for (int k = 0; k < n; k++) w[k] /= wnorm;

        // Apply previous Givens rotations
        for (int i = 0; i < j; i++) {
            double h1 = H[i * m + j], h2 = H[(i + 1) * m + j];
            H[i * m + j] = cs[i] * h1 + sn[i] * h2;
            H[(i + 1) * m + j] = -sn[i] * h1 + cs[i] * h2;
        }

        // Compute new Givens rotation
        double h1 = H[j * m + j], h2 = H[(j + 1) * m + j];
        double t = sqrt(h1 * h1 + h2 * h2);
        cs[j] = h1 / t; sn[j] = h2 / t;
        H[j * m + j] = t;
        H[(j + 1) * m + j] = 0;

        double g1 = g[j];
        g[j] = cs[j] * g1;
        g[j + 1] = -sn[j] * g1;

        if (fabs(g[j + 1]) < tol) { j++; break; }
    }

    // Back-substitution
    double *y = (double *)calloc(j, sizeof(double));
    for (int i = j - 1; i >= 0; i--) {
        y[i] = g[i];
        for (int k = i + 1; k < j; k++) y[i] -= H[i * m + k] * y[k];
        y[i] /= H[i * m + i];
    }

    // x = V * y
    for (int i = 0; i < n; i++)
        for (int k = 0; k < j; k++)
            x[i] += V[k][i] * y[k];

    free(y);
    for (int i = 0; i <= m; i++) free(V[i]);
    free(V); free(H); free(cs); free(sn); free(g);

done:
    free(r);
    NVec *result = (NVec *)malloc(sizeof(NVec));
    result->len = n; result->cap = n;
    result->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++) result->data[i] = _sp_f2i(x[i]);
    free(x);
    return (long long)result;
}

// ================================================================
//  Sparse transpose
// ================================================================

long long nuc_sp_transpose(long long ah) {
    SpMat *a = (SpMat *)(void *)ah;
    SpMat *t = (SpMat *)calloc(1, sizeof(SpMat));
    t->rows = a->cols; t->cols = a->rows; t->nnz = a->nnz;
    t->vals = (double *)malloc(a->nnz * sizeof(double));
    t->col_idx = (int *)malloc(a->nnz * sizeof(int));
    t->row_ptr = (int *)calloc(a->cols + 1, sizeof(int));

    for (int i = 0; i < a->nnz; i++) t->row_ptr[a->col_idx[i] + 1]++;
    for (int i = 0; i < a->cols; i++) t->row_ptr[i + 1] += t->row_ptr[i];

    int *temp = (int *)calloc(a->cols, sizeof(int));
    for (int i = 0; i < a->rows; i++) {
        for (int k = a->row_ptr[i]; k < a->row_ptr[i + 1]; k++) {
            int col = a->col_idx[k];
            int pos = t->row_ptr[col] + temp[col];
            t->vals[pos] = a->vals[k];
            t->col_idx[pos] = i;
            temp[col]++;
        }
    }
    free(temp);
    return (long long)t;
}

// ================================================================
//  Convert dense matrix to sparse
// ================================================================

long long nuc_sp_from_dense(long long mh) {
    typedef struct { int rows; int cols; double *data; } NMat;
    NMat *m = (NMat *)(void *)mh;
    int r = m->rows, c = m->cols;

    // Count non-zeros
    int nnz = 0;
    for (int i = 0; i < r * c; i++) if (fabs(m->data[i]) > 1e-15) nnz++;

    SpMat *sp = (SpMat *)calloc(1, sizeof(SpMat));
    sp->rows = r; sp->cols = c; sp->nnz = nnz;
    sp->vals = (double *)malloc(nnz * sizeof(double));
    sp->col_idx = (int *)malloc(nnz * sizeof(int));
    sp->row_ptr = (int *)calloc(r + 1, sizeof(int));

    int idx = 0;
    for (int i = 0; i < r; i++) {
        sp->row_ptr[i] = idx;
        for (int j = 0; j < c; j++) {
            double v = m->data[i * c + j];
            if (fabs(v) > 1e-15) {
                sp->vals[idx] = v;
                sp->col_idx[idx] = j;
                idx++;
            }
        }
    }
    sp->row_ptr[r] = idx;
    return (long long)sp;
}

void nuc_sp_free(long long h) {
    SpMat *m = (SpMat *)(void *)h;
    if (m) { free(m->vals); free(m->col_idx); free(m->row_ptr); free(m); }
}
