// pca_rt.c — Principal Component Analysis Runtime
// Covariance matrix → Jacobi eigendecomposition → PC projections
// For S12b V4 Appendix K: noise vulnerability manifold
//
// Compile: clang -c pca_rt.c -o target/pca_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _pi2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _pf2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }
typedef struct { long long *data; int len; int cap; } PVec;

// =====================================================
// PCA: compute principal components from data matrix
// =====================================================

// Jacobi eigenvalue algorithm for symmetric matrix
// A is n×n symmetric (stored row-major, modified in place → eigenvalues on diagonal)
// V is n×n (output eigenvectors as columns)
static void jacobi_eigen(double *A, double *V, int n, int max_iter) {
    // Initialize V = identity
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            V[i * n + j] = (i == j) ? 1.0 : 0.0;

    for (int iter = 0; iter < max_iter; iter++) {
        // Find largest off-diagonal element
        double max_val = 0;
        int p = 0, q = 1;
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                if (fabs(A[i * n + j]) > max_val) {
                    max_val = fabs(A[i * n + j]);
                    p = i; q = j;
                }
        if (max_val < 1e-12) break; // converged

        // Compute rotation angle
        double app = A[p * n + p], aqq = A[q * n + q], apq = A[p * n + q];
        double theta;
        if (fabs(app - aqq) < 1e-15)
            theta = 3.14159265358979323846 / 4.0;
        else
            theta = 0.5 * atan2(2.0 * apq, app - aqq);

        double c = cos(theta), s = sin(theta);

        // Apply rotation to A
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

        // Apply rotation to V (eigenvectors)
        for (int i = 0; i < n; i++) {
            double vip = V[i * n + p], viq = V[i * n + q];
            V[i * n + p] = c * vip + s * viq;
            V[i * n + q] = -s * vip + c * viq;
        }
    }
}

// PCA fit: given data matrix X [n_samples × n_features], compute PCs
// Returns handle to PCA result: eigenvalues, eigenvectors, mean, std
typedef struct {
    int n_features;
    int n_components;
    double *mean;       // n_features
    double *std;        // n_features
    double *eigenvalues; // n_features (sorted descending)
    double *eigenvectors; // n_features × n_features (columns are PCs)
    int *sort_idx;       // sorted indices
} PCAResult;

// X_vec: flat Vec of n_samples * n_features f64 values
// Returns PCA handle
long long nuc_pca_fit(long long X_vec, long long n_samples, long long n_features) {
    PVec *xv = (PVec *)(void *)X_vec;
    int n = (int)n_samples, p = (int)n_features;

    PCAResult *pca = (PCAResult *)calloc(1, sizeof(PCAResult));
    pca->n_features = p;
    pca->n_components = p;
    pca->mean = (double *)calloc(p, sizeof(double));
    pca->std = (double *)calloc(p, sizeof(double));
    pca->eigenvalues = (double *)calloc(p, sizeof(double));
    pca->eigenvectors = (double *)calloc((size_t)p * p, sizeof(double));
    pca->sort_idx = (int *)calloc(p, sizeof(int));

    // Compute mean
    for (int i = 0; i < n; i++)
        for (int j = 0; j < p; j++)
            pca->mean[j] += _pi2f(xv->data[i * p + j]);
    for (int j = 0; j < p; j++)
        pca->mean[j] /= n;

    // Compute std
    for (int i = 0; i < n; i++)
        for (int j = 0; j < p; j++) {
            double d = _pi2f(xv->data[i * p + j]) - pca->mean[j];
            pca->std[j] += d * d;
        }
    for (int j = 0; j < p; j++) {
        pca->std[j] = sqrt(pca->std[j] / (n > 1 ? n - 1 : 1));
        if (pca->std[j] < 1e-10) pca->std[j] = 1.0;
    }

    // Build covariance matrix (standardized)
    double *cov = (double *)calloc((size_t)p * p, sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < p; j++) {
            double xj = (_pi2f(xv->data[i * p + j]) - pca->mean[j]) / pca->std[j];
            for (int k = j; k < p; k++) {
                double xk = (_pi2f(xv->data[i * p + k]) - pca->mean[k]) / pca->std[k];
                cov[j * p + k] += xj * xk;
            }
        }
    }
    for (int j = 0; j < p; j++)
        for (int k = j; k < p; k++) {
            cov[j * p + k] /= (n > 1 ? n - 1 : 1);
            cov[k * p + j] = cov[j * p + k]; // symmetric
        }

    // Eigendecomposition
    double *V = (double *)calloc((size_t)p * p, sizeof(double));
    jacobi_eigen(cov, V, p, 200);

    // Extract eigenvalues (diagonal of cov after Jacobi)
    for (int j = 0; j < p; j++)
        pca->eigenvalues[j] = cov[j * p + j];

    // Sort by descending eigenvalue
    for (int j = 0; j < p; j++) pca->sort_idx[j] = j;
    for (int i = 0; i < p; i++)
        for (int j = i + 1; j < p; j++)
            if (pca->eigenvalues[pca->sort_idx[j]] > pca->eigenvalues[pca->sort_idx[i]]) {
                int tmp = pca->sort_idx[i];
                pca->sort_idx[i] = pca->sort_idx[j];
                pca->sort_idx[j] = tmp;
            }

    // Store sorted eigenvectors
    for (int j = 0; j < p; j++) {
        int src = pca->sort_idx[j];
        for (int i = 0; i < p; i++)
            pca->eigenvectors[i * p + j] = V[i * p + src]; // column j = PC j
    }

    free(cov); free(V);
    return (long long)pca;
}

// Project a single sample onto PC k (0-based, 0=PC1)
// sample_vec: Vec of n_features f64 values
long long nuc_pca_project(long long pca_handle, long long sample_vec, long long k) {
    PCAResult *pca = (PCAResult *)(void *)pca_handle;
    PVec *sv = (PVec *)(void *)sample_vec;
    int p = pca->n_features;
    int pc = (int)k;

    double proj = 0;
    for (int j = 0; j < p && j < sv->len; j++) {
        double x_std = (_pi2f(sv->data[j]) - pca->mean[j]) / pca->std[j];
        proj += x_std * pca->eigenvectors[j * p + pc];
    }
    return _pf2i(proj);
}

// Get eigenvalue for PC k (fraction of variance)
long long nuc_pca_variance_ratio(long long pca_handle, long long k) {
    PCAResult *pca = (PCAResult *)(void *)pca_handle;
    int pc = (int)k;
    double total = 0;
    for (int j = 0; j < pca->n_features; j++)
        total += pca->eigenvalues[j];
    double ratio = (total > 1e-15) ? pca->eigenvalues[pca->sort_idx[pc]] / total : 0;
    return _pf2i(ratio);
}

// Get raw eigenvalue for PC k
long long nuc_pca_eigenvalue(long long pca_handle, long long k) {
    PCAResult *pca = (PCAResult *)(void *)pca_handle;
    return _pf2i(pca->eigenvalues[pca->sort_idx[(int)k]]);
}

void nuc_pca_free(long long pca_handle) {
    PCAResult *pca = (PCAResult *)(void *)pca_handle;
    if (!pca) return;
    free(pca->mean); free(pca->std);
    free(pca->eigenvalues); free(pca->eigenvectors);
    free(pca->sort_idx); free(pca);
}
