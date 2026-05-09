// tensor_rt.c — Tensor operations for Nucleor
// Provides matrix solve, matmul, transpose for Ridge regression
// All f64 values passed as i64 (bitcast), same pattern as quantum_rt.c
//
// Compile: clang -c tensor_rt.c -o target/tensor_rt.obj

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

typedef union { long long i; double f; } tf64;

// --- Flat matrix: rows*cols doubles, row-major ---
typedef struct {
    int rows;
    int cols;
    double *data;
} NMat;

static NMat *mat_alloc(int rows, int cols) {
    NMat *m = (NMat *)malloc(sizeof(NMat));
    m->rows = rows;
    m->cols = cols;
    m->data = (double *)calloc(rows * cols, sizeof(double));
    return m;
}

// --- Exposed functions (extern fn from Nucleor) ---

// Create a rows x cols zero matrix. Returns handle.
long long nuc_mat_new(long long rows, long long cols) {
    return (long long)mat_alloc((int)rows, (int)cols);
}

long long nuc_mat_rows(long long handle) {
    NMat *m = (NMat *)(void *)handle;
    return (long long)m->rows;
}

long long nuc_mat_cols(long long handle) {
    NMat *m = (NMat *)(void *)handle;
    return (long long)m->cols;
}

// Get element as f64 (bitcast i64)
long long nuc_mat_get(long long handle, long long r, long long c) {
    NMat *m = (NMat *)(void *)handle;
    tf64 v;
    v.f = m->data[(int)r * m->cols + (int)c];
    return v.i;
}

// Set element from f64 (bitcast i64)
void nuc_mat_set(long long handle, long long r, long long c, long long val) {
    NMat *m = (NMat *)(void *)handle;
    tf64 v; v.i = val;
    m->data[(int)r * m->cols + (int)c] = v.f;
}

// Matrix multiply: C = A @ B. Returns new matrix handle.
long long nuc_mat_mul(long long a_handle, long long b_handle) {
    NMat *a = (NMat *)(void *)a_handle;
    NMat *b = (NMat *)(void *)b_handle;
    if (a->cols != b->rows) return 0; // dimension mismatch
    NMat *c = mat_alloc(a->rows, b->cols);
    for (int i = 0; i < a->rows; i++) {
        for (int j = 0; j < b->cols; j++) {
            double sum = 0.0;
            for (int k = 0; k < a->cols; k++) {
                sum += a->data[i * a->cols + k] * b->data[k * b->cols + j];
            }
            c->data[i * c->cols + j] = sum;
        }
    }
    return (long long)c;
}

// Transpose: returns new matrix
long long nuc_mat_transpose(long long handle) {
    NMat *m = (NMat *)(void *)handle;
    NMat *t = mat_alloc(m->cols, m->rows);
    for (int i = 0; i < m->rows; i++) {
        for (int j = 0; j < m->cols; j++) {
            t->data[j * t->cols + i] = m->data[i * m->cols + j];
        }
    }
    return (long long)t;
}

// Add lambda * I to square matrix (in-place)
void nuc_mat_add_lambda_I(long long handle, long long lambda_bits) {
    NMat *m = (NMat *)(void *)handle;
    tf64 lam; lam.i = lambda_bits;
    int n = m->rows < m->cols ? m->rows : m->cols;
    for (int i = 0; i < n; i++) {
        m->data[i * m->cols + i] += lam.f;
    }
}

// Solve Ax = b via Gaussian elimination with partial pivoting
// A is n x n, b is n x 1. Returns x as n x 1 matrix.
// Does NOT modify A or b.
long long nuc_mat_solve(long long a_handle, long long b_handle) {
    NMat *A_orig = (NMat *)(void *)a_handle;
    NMat *b_orig = (NMat *)(void *)b_handle;
    int n = A_orig->rows;

    // Copy A and b (don't modify originals)
    double *A = (double *)malloc(n * n * sizeof(double));
    double *b = (double *)malloc(n * sizeof(double));
    memcpy(A, A_orig->data, n * n * sizeof(double));
    for (int i = 0; i < n; i++) b[i] = b_orig->data[i];

    // Forward elimination with partial pivoting
    for (int k = 0; k < n; k++) {
        // Find pivot
        int max_row = k;
        double max_val = fabs(A[k * n + k]);
        for (int i = k + 1; i < n; i++) {
            double v = fabs(A[i * n + k]);
            if (v > max_val) { max_val = v; max_row = i; }
        }
        // Swap rows
        if (max_row != k) {
            for (int j = 0; j < n; j++) {
                double tmp = A[k * n + j];
                A[k * n + j] = A[max_row * n + j];
                A[max_row * n + j] = tmp;
            }
            double tmp = b[k]; b[k] = b[max_row]; b[max_row] = tmp;
        }
        // Eliminate
        double pivot = A[k * n + k];
        if (fabs(pivot) < 1e-15) continue; // singular
        for (int i = k + 1; i < n; i++) {
            double factor = A[i * n + k] / pivot;
            for (int j = k; j < n; j++) {
                A[i * n + j] -= factor * A[k * n + j];
            }
            b[i] -= factor * b[k];
        }
    }

    // Back substitution
    NMat *x = mat_alloc(n, 1);
    for (int i = n - 1; i >= 0; i--) {
        double sum = b[i];
        for (int j = i + 1; j < n; j++) {
            sum -= A[i * n + j] * x->data[j];
        }
        double diag = A[i * n + i];
        x->data[i] = (fabs(diag) > 1e-15) ? sum / diag : 0.0;
    }

    free(A);
    free(b);
    return (long long)x;
}

// Copy matrix from flat Vec (Nucleor Vec<f64>) into NMat
// vec_ptr is a Nucleor Vec handle, we read n_rows * n_cols values
long long nuc_mat_from_vec(long long vec_ptr, long long n_rows, long long n_cols) {
    // Access Nucleor Vec internals (same layout as NVec in nucleor_llvm_rt.c)
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec_ptr;
    NMat *m = mat_alloc((int)n_rows, (int)n_cols);
    int total = (int)n_rows * (int)n_cols;
    for (int i = 0; i < total && i < v->len; i++) {
        tf64 val; val.i = v->data[i];
        m->data[i] = val.f;
    }
    return (long long)m;
}

// Copy Vec of f64 into n x 1 matrix
long long nuc_mat_from_vec_col(long long vec_ptr, long long n) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec_ptr;
    NMat *m = mat_alloc((int)n, 1);
    for (int i = 0; i < (int)n && i < v->len; i++) {
        tf64 val; val.i = v->data[i];
        m->data[i] = val.f;
    }
    return (long long)m;
}

// Standardize matrix columns in-place, returns [mu_mat, sigma_mat] as two n_cols x 1 matrices
// packed into a single 2-element array: [0]=mu handle, [1]=sigma handle
long long nuc_mat_standardize(long long handle) {
    NMat *m = (NMat *)(void *)handle;
    int nr = m->rows, nc = m->cols;
    NMat *mu = mat_alloc(nc, 1);
    NMat *sigma = mat_alloc(nc, 1);

    for (int j = 0; j < nc; j++) {
        double sum = 0;
        for (int i = 0; i < nr; i++) sum += m->data[i * nc + j];
        double mean = sum / nr;
        mu->data[j] = mean;

        double var = 0;
        for (int i = 0; i < nr; i++) {
            double d = m->data[i * nc + j] - mean;
            var += d * d;
        }
        double std = sqrt(var / nr) + 1e-10;
        sigma->data[j] = std;

        // Standardize in-place
        for (int i = 0; i < nr; i++) {
            m->data[i * nc + j] = (m->data[i * nc + j] - mean) / std;
        }
    }

    // Pack mu and sigma handles into a small array
    long long *result = (long long *)malloc(2 * sizeof(long long));
    result[0] = (long long)mu;
    result[1] = (long long)sigma;
    return (long long)result;
}

// Get mu or sigma from standardize result
long long nuc_mat_std_mu(long long result) {
    long long *r = (long long *)(void *)result;
    return r[0];
}
long long nuc_mat_std_sigma(long long result) {
    long long *r = (long long *)(void *)result;
    return r[1];
}

// Compute MAE between two n x 1 matrices
long long nuc_mat_mae(long long a_handle, long long b_handle) {
    NMat *a = (NMat *)(void *)a_handle;
    NMat *b = (NMat *)(void *)b_handle;
    int n = a->rows;
    double sum = 0;
    for (int i = 0; i < n; i++) {
        sum += fabs(a->data[i] - b->data[i]);
    }
    tf64 r; r.f = sum / n;
    return r.i;
}

// Clip all values in matrix to [lo, hi]
void nuc_mat_clip(long long handle, long long lo_bits, long long hi_bits) {
    NMat *m = (NMat *)(void *)handle;
    tf64 lo, hi; lo.i = lo_bits; hi.i = hi_bits;
    int total = m->rows * m->cols;
    for (int i = 0; i < total; i++) {
        if (m->data[i] < lo.f) m->data[i] = lo.f;
        if (m->data[i] > hi.f) m->data[i] = hi.f;
    }
}

// Full Ridge regression: closed-form solution
// X: n_samples x n_feats, y: n_samples x 1, lambda: regularization
// Returns weights: n_feats x 1
long long nuc_ridge_solve(long long X_handle, long long y_handle, long long lambda_bits) {
    NMat *X = (NMat *)(void *)X_handle;
    NMat *y = (NMat *)(void *)y_handle;
    tf64 lam; lam.i = lambda_bits;
    int n = X->rows, p = X->cols;

    // Standardize X (copy first)
    NMat *Xs = mat_alloc(n, p);
    memcpy(Xs->data, X->data, n * p * sizeof(double));
    double *mu = (double *)malloc(p * sizeof(double));
    double *sig = (double *)malloc(p * sizeof(double));
    for (int j = 0; j < p; j++) {
        double sum = 0;
        for (int i = 0; i < n; i++) sum += Xs->data[i * p + j];
        mu[j] = sum / n;
        double var = 0;
        for (int i = 0; i < n; i++) {
            double d = Xs->data[i * p + j] - mu[j];
            var += d * d;
        }
        sig[j] = sqrt(var / n) + 1e-10;
        for (int i = 0; i < n; i++) {
            Xs->data[i * p + j] = (Xs->data[i * p + j] - mu[j]) / sig[j];
        }
    }

    // A = X^T X + lambda * I
    double *A = (double *)calloc(p * p, sizeof(double));
    for (int i = 0; i < p; i++) {
        for (int j = 0; j < p; j++) {
            double sum = 0;
            for (int k = 0; k < n; k++) {
                sum += Xs->data[k * p + i] * Xs->data[k * p + j];
            }
            A[i * p + j] = sum;
        }
        A[i * p + i] += lam.f;
    }

    // b = X^T y
    double *b = (double *)calloc(p, sizeof(double));
    for (int i = 0; i < p; i++) {
        for (int k = 0; k < n; k++) {
            b[i] += Xs->data[k * p + i] * y->data[k];
        }
    }

    // Solve Aw = b via Gaussian elimination
    for (int k = 0; k < p; k++) {
        int max_row = k;
        double max_val = fabs(A[k * p + k]);
        for (int i = k + 1; i < p; i++) {
            if (fabs(A[i * p + k]) > max_val) {
                max_val = fabs(A[i * p + k]);
                max_row = i;
            }
        }
        if (max_row != k) {
            for (int j = 0; j < p; j++) {
                double tmp = A[k * p + j]; A[k * p + j] = A[max_row * p + j]; A[max_row * p + j] = tmp;
            }
            double tmp = b[k]; b[k] = b[max_row]; b[max_row] = tmp;
        }
        double pivot = A[k * p + k];
        if (fabs(pivot) < 1e-15) continue;
        for (int i = k + 1; i < p; i++) {
            double factor = A[i * p + k] / pivot;
            for (int j = k; j < p; j++) A[i * p + j] -= factor * A[k * p + j];
            b[i] -= factor * b[k];
        }
    }

    double *w = (double *)calloc(p, sizeof(double));
    for (int i = p - 1; i >= 0; i--) {
        double sum = b[i];
        for (int j = i + 1; j < p; j++) sum -= A[i * p + j] * w[j];
        w[i] = (fabs(A[i * p + i]) > 1e-15) ? sum / A[i * p + i] : 0.0;
    }

    // Pack result: [w, mu, sig] as 3-part structure
    // Store in a NMat-like thing: weights in col 0, mu in col 1, sigma in col 2
    NMat *result = mat_alloc(p, 3);
    for (int i = 0; i < p; i++) {
        result->data[i * 3 + 0] = w[i];
        result->data[i * 3 + 1] = mu[i];
        result->data[i * 3 + 2] = sig[i];
    }

    free(A); free(b); free(w); free(mu); free(sig);
    free(Xs->data); free(Xs);
    return (long long)result;
}

// Predict using Ridge model: returns predictions as n x 1 matrix
long long nuc_ridge_predict(long long model_handle, long long X_handle) {
    NMat *model = (NMat *)(void *)model_handle; // p x 3 [w, mu, sig]
    NMat *X = (NMat *)(void *)X_handle;
    int n = X->rows, p = X->cols;

    NMat *pred = mat_alloc(n, 1);
    for (int i = 0; i < n; i++) {
        double sum = 0;
        for (int j = 0; j < p; j++) {
            double x_std = (X->data[i * p + j] - model->data[j * 3 + 1]) / model->data[j * 3 + 2];
            sum += model->data[j * 3 + 0] * x_std;
        }
        // Clip to [0, 1]
        if (sum < 0) sum = 0;
        if (sum > 1) sum = 1;
        pred->data[i] = sum;
    }
    return (long long)pred;
}

// Full Ridge CV: returns MAE as f64
long long nuc_ridge_cv(long long X_vec, long long y_vec,
                        long long n_samples, long long n_feats,
                        long long k_folds, long long lambda_bits) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *xv = (NVec *)(void *)X_vec;
    NVec *yv = (NVec *)(void *)y_vec;
    tf64 lam; lam.i = lambda_bits;
    int n = (int)n_samples, p = (int)n_feats, k = (int)k_folds;
    int fold_size = n / k;

    double total_err = 0;
    int total_test = 0;

    for (int fold = 0; fold < k; fold++) {
        int test_start = fold * fold_size;
        int test_end = (fold == k - 1) ? n : test_start + fold_size;
        int n_test = test_end - test_start;
        int n_train = n - n_test;

        // Build train X, y
        NMat *X_train = mat_alloc(n_train, p);
        NMat *y_train = mat_alloc(n_train, 1);
        NMat *X_test = mat_alloc(n_test, p);
        NMat *y_test = mat_alloc(n_test, 1);

        int ti = 0, vi = 0;
        for (int i = 0; i < n; i++) {
            if (i >= test_start && i < test_end) {
                for (int j = 0; j < p; j++) {
                    tf64 v; v.i = xv->data[i * p + j];
                    X_test->data[vi * p + j] = v.f;
                }
                tf64 yval; yval.i = yv->data[i];
                y_test->data[vi] = yval.f;
                vi++;
            } else {
                for (int j = 0; j < p; j++) {
                    tf64 v; v.i = xv->data[i * p + j];
                    X_train->data[ti * p + j] = v.f;
                }
                tf64 yval; yval.i = yv->data[i];
                y_train->data[ti] = yval.f;
                ti++;
            }
        }

        // Train
        long long model = nuc_ridge_solve((long long)X_train, (long long)y_train, lambda_bits);

        // Predict
        long long preds = nuc_ridge_predict(model, (long long)X_test);
        NMat *pred_mat = (NMat *)(void *)preds;

        // Accumulate error
        for (int i = 0; i < n_test; i++) {
            total_err += fabs(pred_mat->data[i] - y_test->data[i]);
        }
        total_test += n_test;

        // Free
        free(X_train->data); free(X_train);
        free(y_train->data); free(y_train);
        free(X_test->data); free(X_test);
        free(y_test->data); free(y_test);
        NMat *m = (NMat *)(void *)model; free(m->data); free(m);
        free(pred_mat->data); free(pred_mat);
    }

    tf64 result;
    result.f = total_err / total_test;
    return result.i;
}
