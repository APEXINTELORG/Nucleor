// linalg_rt.c — Extended Dense Linear Algebra for Nucleor
// Adds LU, QR, Cholesky, eigenvalues, SVD, inverse, determinant, norms
// to complement the basic operations in tensor_rt.c.
// All f64 values passed as i64 (bitcast), same pattern as tensor_rt.c.
//
// Compile: clang -c stdlib/runtime/linalg_rt.c -o target/linalg_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _la_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _la_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// NMat must match tensor_rt.c layout exactly
typedef struct { int rows; int cols; double *data; } LAMat;

static LAMat *la_alloc(int r, int c) {
    LAMat *m = (LAMat *)malloc(sizeof(LAMat));
    m->rows = r; m->cols = c;
    m->data = (double *)calloc(r * c, sizeof(double));
    return m;
}

static void la_copy(LAMat *dst, LAMat *src) {
    memcpy(dst->data, src->data, src->rows * src->cols * sizeof(double));
}

// ================================================================
//  Matrix Addition / Subtraction / Scale
// ================================================================

long long nuc_mat_add(long long ah, long long bh) {
    LAMat *a = (LAMat *)(void *)ah, *b = (LAMat *)(void *)bh;
    if (a->rows != b->rows || a->cols != b->cols) return 0;
    LAMat *c = la_alloc(a->rows, a->cols);
    int n = a->rows * a->cols;
    for (int i = 0; i < n; i++) c->data[i] = a->data[i] + b->data[i];
    return (long long)c;
}

long long nuc_mat_sub(long long ah, long long bh) {
    LAMat *a = (LAMat *)(void *)ah, *b = (LAMat *)(void *)bh;
    if (a->rows != b->rows || a->cols != b->cols) return 0;
    LAMat *c = la_alloc(a->rows, a->cols);
    int n = a->rows * a->cols;
    for (int i = 0; i < n; i++) c->data[i] = a->data[i] - b->data[i];
    return (long long)c;
}

long long nuc_mat_scale(long long ah, long long s_bits) {
    LAMat *a = (LAMat *)(void *)ah;
    double s = _la_i2f(s_bits);
    LAMat *c = la_alloc(a->rows, a->cols);
    int n = a->rows * a->cols;
    for (int i = 0; i < n; i++) c->data[i] = a->data[i] * s;
    return (long long)c;
}

// ================================================================
//  Trace
// ================================================================

long long nuc_mat_trace(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int n = a->rows < a->cols ? a->rows : a->cols;
    double tr = 0;
    for (int i = 0; i < n; i++) tr += a->data[i * a->cols + i];
    return _la_f2i(tr);
}

// ================================================================
//  Norms: type 1=1-norm, 2=frobenius, 3=inf-norm
// ================================================================

long long nuc_mat_norm(long long ah, long long type) {
    LAMat *a = (LAMat *)(void *)ah;
    int r = a->rows, c = a->cols;
    double result = 0;

    if (type == 1) {
        // max column sum
        for (int j = 0; j < c; j++) {
            double col_sum = 0;
            for (int i = 0; i < r; i++) col_sum += fabs(a->data[i * c + j]);
            if (col_sum > result) result = col_sum;
        }
    } else if (type == 3) {
        // max row sum
        for (int i = 0; i < r; i++) {
            double row_sum = 0;
            for (int j = 0; j < c; j++) row_sum += fabs(a->data[i * c + j]);
            if (row_sum > result) result = row_sum;
        }
    } else {
        // Frobenius norm
        double sum = 0;
        for (int i = 0; i < r * c; i++) sum += a->data[i] * a->data[i];
        result = sqrt(sum);
    }
    return _la_f2i(result);
}

// ================================================================
//  Determinant (via LU)
// ================================================================

long long nuc_mat_det(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int n = a->rows;
    if (n != a->cols) return _la_f2i(0.0);

    double *A = (double *)malloc(n * n * sizeof(double));
    memcpy(A, a->data, n * n * sizeof(double));
    double det = 1.0;
    int sign = 1;

    for (int k = 0; k < n; k++) {
        int max_row = k;
        double max_val = fabs(A[k * n + k]);
        for (int i = k + 1; i < n; i++) {
            if (fabs(A[i * n + k]) > max_val) {
                max_val = fabs(A[i * n + k]);
                max_row = i;
            }
        }
        if (max_val < 1e-15) { free(A); return _la_f2i(0.0); }
        if (max_row != k) {
            for (int j = 0; j < n; j++) {
                double tmp = A[k * n + j]; A[k * n + j] = A[max_row * n + j]; A[max_row * n + j] = tmp;
            }
            sign = -sign;
        }
        det *= A[k * n + k];
        for (int i = k + 1; i < n; i++) {
            double factor = A[i * n + k] / A[k * n + k];
            for (int j = k + 1; j < n; j++) A[i * n + j] -= factor * A[k * n + j];
        }
    }
    free(A);
    return _la_f2i(det * sign);
}

// ================================================================
//  Inverse (via Gauss-Jordan)
// ================================================================

long long nuc_mat_inv(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int n = a->rows;
    if (n != a->cols) return 0;

    double *aug = (double *)calloc(n * 2 * n, sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i * 2 * n + j] = a->data[i * n + j];
        aug[i * 2 * n + n + i] = 1.0;
    }

    for (int k = 0; k < n; k++) {
        int max_row = k;
        double max_val = fabs(aug[k * 2 * n + k]);
        for (int i = k + 1; i < n; i++) {
            if (fabs(aug[i * 2 * n + k]) > max_val) {
                max_val = fabs(aug[i * 2 * n + k]);
                max_row = i;
            }
        }
        if (max_val < 1e-15) { free(aug); return 0; } // singular
        if (max_row != k) {
            for (int j = 0; j < 2 * n; j++) {
                double tmp = aug[k * 2 * n + j];
                aug[k * 2 * n + j] = aug[max_row * 2 * n + j];
                aug[max_row * 2 * n + j] = tmp;
            }
        }
        double pivot = aug[k * 2 * n + k];
        for (int j = 0; j < 2 * n; j++) aug[k * 2 * n + j] /= pivot;
        for (int i = 0; i < n; i++) {
            if (i == k) continue;
            double factor = aug[i * 2 * n + k];
            for (int j = 0; j < 2 * n; j++) aug[i * 2 * n + j] -= factor * aug[k * 2 * n + j];
        }
    }

    LAMat *inv = la_alloc(n, n);
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            inv->data[i * n + j] = aug[i * 2 * n + n + j];

    free(aug);
    return (long long)inv;
}

// ================================================================
//  LU Decomposition (PA = LU, partial pivoting)
//  Returns packed handle: L, U, P as 3 matrices
// ================================================================

typedef struct { long long L; long long U; long long P; } LUResult;

long long nuc_mat_lu(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int n = a->rows;
    if (n != a->cols) return 0;

    LAMat *L = la_alloc(n, n);
    LAMat *U = la_alloc(n, n);
    LAMat *P = la_alloc(n, n);
    memcpy(U->data, a->data, n * n * sizeof(double));
    for (int i = 0; i < n; i++) { L->data[i * n + i] = 1.0; P->data[i * n + i] = 1.0; }

    for (int k = 0; k < n; k++) {
        int max_row = k;
        double max_val = fabs(U->data[k * n + k]);
        for (int i = k + 1; i < n; i++) {
            if (fabs(U->data[i * n + k]) > max_val) {
                max_val = fabs(U->data[i * n + k]);
                max_row = i;
            }
        }
        if (max_row != k) {
            for (int j = 0; j < n; j++) {
                double tmp;
                tmp = U->data[k * n + j]; U->data[k * n + j] = U->data[max_row * n + j]; U->data[max_row * n + j] = tmp;
                tmp = P->data[k * n + j]; P->data[k * n + j] = P->data[max_row * n + j]; P->data[max_row * n + j] = tmp;
            }
            for (int j = 0; j < k; j++) {
                double tmp = L->data[k * n + j]; L->data[k * n + j] = L->data[max_row * n + j]; L->data[max_row * n + j] = tmp;
            }
        }
        if (fabs(U->data[k * n + k]) < 1e-15) continue;
        for (int i = k + 1; i < n; i++) {
            double factor = U->data[i * n + k] / U->data[k * n + k];
            L->data[i * n + k] = factor;
            for (int j = k; j < n; j++) U->data[i * n + j] -= factor * U->data[k * n + j];
        }
    }

    LUResult *res = (LUResult *)malloc(sizeof(LUResult));
    res->L = (long long)L; res->U = (long long)U; res->P = (long long)P;
    return (long long)res;
}

long long nuc_mat_lu_L(long long h) { return ((LUResult *)(void *)h)->L; }
long long nuc_mat_lu_U(long long h) { return ((LUResult *)(void *)h)->U; }
long long nuc_mat_lu_P(long long h) { return ((LUResult *)(void *)h)->P; }

// ================================================================
//  QR Factorization (Householder)
// ================================================================

typedef struct { long long Q; long long R; } QRResult;

long long nuc_mat_qr(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int m = a->rows, n = a->cols;

    LAMat *R = la_alloc(m, n);
    memcpy(R->data, a->data, m * n * sizeof(double));
    LAMat *Q = la_alloc(m, m);
    for (int i = 0; i < m; i++) Q->data[i * m + i] = 1.0;

    int kmax = m < n ? m : n;
    double *v = (double *)malloc(m * sizeof(double));

    for (int k = 0; k < kmax; k++) {
        // Build Householder vector
        double norm = 0;
        for (int i = k; i < m; i++) {
            v[i] = R->data[i * n + k];
            norm += v[i] * v[i];
        }
        norm = sqrt(norm);
        if (norm < 1e-15) continue;

        double sign = (v[k] >= 0) ? 1.0 : -1.0;
        v[k] += sign * norm;

        double vnorm = 0;
        for (int i = k; i < m; i++) vnorm += v[i] * v[i];
        if (vnorm < 1e-30) continue;
        double scale = 2.0 / vnorm;

        // Apply H = I - 2*v*v^T/||v||^2 to R
        for (int j = k; j < n; j++) {
            double dot = 0;
            for (int i = k; i < m; i++) dot += v[i] * R->data[i * n + j];
            for (int i = k; i < m; i++) R->data[i * n + j] -= scale * v[i] * dot;
        }

        // Apply H to Q
        for (int j = 0; j < m; j++) {
            double dot = 0;
            for (int i = k; i < m; i++) dot += v[i] * Q->data[i * m + j];
            for (int i = k; i < m; i++) Q->data[i * m + j] -= scale * v[i] * dot;
        }
    }

    free(v);
    // Q is stored transposed due to accumulation; transpose it
    LAMat *Qt = la_alloc(m, m);
    for (int i = 0; i < m; i++)
        for (int j = 0; j < m; j++)
            Qt->data[i * m + j] = Q->data[j * m + i];
    free(Q->data); free(Q);

    QRResult *res = (QRResult *)malloc(sizeof(QRResult));
    res->Q = (long long)Qt; res->R = (long long)R;
    return (long long)res;
}

long long nuc_mat_qr_Q(long long h) { return ((QRResult *)(void *)h)->Q; }
long long nuc_mat_qr_R(long long h) { return ((QRResult *)(void *)h)->R; }

// ================================================================
//  Cholesky Decomposition (A = L L^T, A must be SPD)
// ================================================================

long long nuc_mat_cholesky(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int n = a->rows;
    if (n != a->cols) return 0;

    LAMat *L = la_alloc(n, n);
    for (int i = 0; i < n; i++) {
        for (int j = 0; j <= i; j++) {
            double sum = 0;
            if (j == i) {
                for (int k = 0; k < j; k++) sum += L->data[j * n + k] * L->data[j * n + k];
                double val = a->data[j * n + j] - sum;
                if (val <= 0) { free(L->data); free(L); return 0; } // not SPD
                L->data[j * n + j] = sqrt(val);
            } else {
                for (int k = 0; k < j; k++) sum += L->data[i * n + k] * L->data[j * n + k];
                L->data[i * n + j] = (a->data[i * n + j] - sum) / L->data[j * n + j];
            }
        }
    }
    return (long long)L;
}

// ================================================================
//  Eigenvalues/Eigenvectors (QR iteration for symmetric matrices)
// ================================================================

typedef struct { long long vals; long long vecs; } EigResult;

long long nuc_mat_eig(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int n = a->rows;
    if (n != a->cols) return 0;

    // Jacobi eigenvalue algorithm for symmetric matrices
    double *A = (double *)malloc(n * n * sizeof(double));
    memcpy(A, a->data, n * n * sizeof(double));
    double *V = (double *)calloc(n * n, sizeof(double));
    for (int i = 0; i < n; i++) V[i * n + i] = 1.0;

    for (int iter = 0; iter < 200; iter++) {
        double off = 0;
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                off += A[i * n + j] * A[i * n + j];
        if (off < 1e-24) break;

        int p = 0, q = 1;
        double max_off = 0;
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                if (fabs(A[i * n + j]) > max_off) { max_off = fabs(A[i * n + j]); p = i; q = j; }

        double app = A[p * n + p], aqq = A[q * n + q], apq = A[p * n + q];
        double theta;
        if (fabs(app - aqq) < 1e-15) theta = 3.14159265358979323846 / 4.0;
        else theta = 0.5 * atan2(2.0 * apq, app - aqq);

        double c = cos(theta), s = sin(theta);

        for (int i = 0; i < n; i++) {
            double aip = A[i * n + p], aiq = A[i * n + q];
            A[i * n + p] = c * aip + s * aiq;
            A[i * n + q] = -s * aip + c * aiq;
        }
        for (int j = 0; j < n; j++) {
            double apj = A[p * n + j], aqj = A[q * n + j];
            A[p * n + j] = c * apj + s * aqj;
            A[q * n + j] = -s * apj + c * aqj;
        }
        for (int i = 0; i < n; i++) {
            double vip = V[i * n + p], viq = V[i * n + q];
            V[i * n + p] = c * vip + s * viq;
            V[i * n + q] = -s * vip + c * viq;
        }
    }

    // eigenvalues = diagonal of A
    LAMat *vals = la_alloc(n, 1);
    for (int i = 0; i < n; i++) vals->data[i] = A[i * n + i];

    // eigenvectors = columns of V stored as n x n matrix
    LAMat *vecs = la_alloc(n, n);
    memcpy(vecs->data, V, n * n * sizeof(double));

    free(A); free(V);

    EigResult *res = (EigResult *)malloc(sizeof(EigResult));
    res->vals = (long long)vals; res->vecs = (long long)vecs;
    return (long long)res;
}

long long nuc_mat_eig_vals(long long h) { return ((EigResult *)(void *)h)->vals; }
long long nuc_mat_eig_vecs(long long h) { return ((EigResult *)(void *)h)->vecs; }

// ================================================================
//  SVD (via eigendecomposition of A^T A)
// ================================================================

typedef struct { long long U; long long S; long long V; } SVDResult;

long long nuc_mat_svd(long long ah) {
    LAMat *a = (LAMat *)(void *)ah;
    int m = a->rows, n = a->cols;

    // Compute A^T A (n x n)
    LAMat *ata = la_alloc(n, n);
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            double sum = 0;
            for (int k = 0; k < m; k++) sum += a->data[k * n + i] * a->data[k * n + j];
            ata->data[i * n + j] = sum;
        }

    // Eigendecompose A^T A = V * D * V^T
    long long eig_h = nuc_mat_eig((long long)ata);
    EigResult *eig = (EigResult *)(void *)eig_h;
    LAMat *eigvals = (LAMat *)(void *)eig->vals;
    LAMat *Vmat = (LAMat *)(void *)eig->vecs;

    // Sort eigenvalues descending
    int *order = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) order[i] = i;
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (eigvals->data[order[j]] > eigvals->data[order[i]]) {
                int tmp = order[i]; order[i] = order[j]; order[j] = tmp;
            }

    // Singular values = sqrt(eigenvalues)
    int k = m < n ? m : n;
    LAMat *S = la_alloc(k, 1);
    for (int i = 0; i < k; i++) {
        double ev = eigvals->data[order[i]];
        S->data[i] = (ev > 0) ? sqrt(ev) : 0.0;
    }

    // V = reordered eigenvectors
    LAMat *Vr = la_alloc(n, n);
    for (int j = 0; j < n; j++)
        for (int i = 0; i < n; i++)
            Vr->data[i * n + j] = Vmat->data[i * n + order[j]];

    // U = A * V * diag(1/S)
    LAMat *U = la_alloc(m, k);
    for (int j = 0; j < k; j++) {
        if (S->data[j] < 1e-15) continue;
        double inv_s = 1.0 / S->data[j];
        for (int i = 0; i < m; i++) {
            double sum = 0;
            for (int l = 0; l < n; l++) sum += a->data[i * n + l] * Vr->data[l * n + j];
            U->data[i * k + j] = sum * inv_s;
        }
    }

    free(order);
    free(ata->data); free(ata);
    free(eigvals->data); free(eigvals);
    free(Vmat->data); free(Vmat);
    free(eig);

    SVDResult *res = (SVDResult *)malloc(sizeof(SVDResult));
    res->U = (long long)U; res->S = (long long)S; res->V = (long long)Vr;
    return (long long)res;
}

long long nuc_mat_svd_U(long long h) { return ((SVDResult *)(void *)h)->U; }
long long nuc_mat_svd_S(long long h) { return ((SVDResult *)(void *)h)->S; }
long long nuc_mat_svd_V(long long h) { return ((SVDResult *)(void *)h)->V; }

// ================================================================
//  Numerical Rank
// ================================================================

long long nuc_mat_rank(long long ah, long long tol_bits) {
    LAMat *a = (LAMat *)(void *)ah;
    double tol = _la_i2f(tol_bits);
    long long svd_h = nuc_mat_svd(ah);
    SVDResult *svd = (SVDResult *)(void *)svd_h;
    LAMat *S = (LAMat *)(void *)svd->S;
    int rank = 0;
    for (int i = 0; i < S->rows; i++) {
        if (S->data[i] > tol) rank++;
    }
    // Don't free SVD results here; caller manages lifetime
    return (long long)rank;
}

// ================================================================
//  Identity matrix
// ================================================================

long long nuc_mat_eye(long long n) {
    LAMat *m = la_alloc((int)n, (int)n);
    for (int i = 0; i < (int)n; i++) m->data[i * (int)n + i] = 1.0;
    return (long long)m;
}

// ================================================================
//  Matrix free
// ================================================================

void nuc_mat_free(long long h) {
    LAMat *m = (LAMat *)(void *)h;
    if (m) { free(m->data); free(m); }
}
