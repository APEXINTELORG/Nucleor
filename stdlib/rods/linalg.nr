// =====================================================
// rods/linalg — Dense Linear Algebra
// =====================================================
// Import: import "stdlib/rods/linalg.nr"
// Provides: matrix creation, basic ops, decompositions
//   (LU, QR, Cholesky, eigen, SVD), rank, identity, solve,
//   standardize, ridge regression. All values are f64 bitcast to i64.
// =====================================================

#cfile "../runtime/tensor_rt.c"
#cfile "../runtime/linalg_rt.c"

// --- Matrix lifecycle (from tensor_rt) ---
extern fn nuc_mat_new(rows: i64, cols: i64) -> i64;
extern fn nuc_mat_eye(n: i64) -> i64;
extern fn nuc_mat_free(h: i64);
extern fn nuc_mat_rows(h: i64) -> i64;
extern fn nuc_mat_cols(h: i64) -> i64;
extern fn nuc_mat_get(h: i64, r: i64, c: i64) -> i64;
extern fn nuc_mat_set(h: i64, r: i64, c: i64, val: i64);

// --- Basic arithmetic ---
extern fn nuc_mat_add(a: i64, b: i64) -> i64;
extern fn nuc_mat_sub(a: i64, b: i64) -> i64;
extern fn nuc_mat_scale(a: i64, s_bits: i64) -> i64;
extern fn nuc_mat_mul(a: i64, b: i64) -> i64;
extern fn nuc_mat_transpose(h: i64) -> i64;
extern fn nuc_mat_trace(h: i64) -> i64;
extern fn nuc_mat_norm(h: i64, kind: i64) -> i64;
extern fn nuc_mat_det(h: i64) -> i64;
extern fn nuc_mat_inv(h: i64) -> i64;
extern fn nuc_mat_rank(h: i64, tol_bits: i64) -> i64;
extern fn nuc_mat_solve(a: i64, b: i64) -> i64;

// --- Decompositions ---
extern fn nuc_mat_lu(h: i64) -> i64;
extern fn nuc_mat_lu_L(h: i64) -> i64;
extern fn nuc_mat_lu_U(h: i64) -> i64;
extern fn nuc_mat_lu_P(h: i64) -> i64;

extern fn nuc_mat_qr(h: i64) -> i64;
extern fn nuc_mat_qr_Q(h: i64) -> i64;
extern fn nuc_mat_qr_R(h: i64) -> i64;

extern fn nuc_mat_cholesky(h: i64) -> i64;

extern fn nuc_mat_eig(h: i64) -> i64;
extern fn nuc_mat_eig_vals(h: i64) -> i64;
extern fn nuc_mat_eig_vecs(h: i64) -> i64;

extern fn nuc_mat_svd(h: i64) -> i64;
extern fn nuc_mat_svd_U(h: i64) -> i64;
extern fn nuc_mat_svd_S(h: i64) -> i64;
extern fn nuc_mat_svd_V(h: i64) -> i64;

// --- Ridge regression ---
extern fn nuc_ridge_solve(X: i64, y: i64, lambda_bits: i64) -> i64;
extern fn nuc_ridge_predict(model: i64, X: i64) -> i64;

// Nucleor-friendly wrappers use the `linalg_` prefix.

fn linalg_new(rows: i64, cols: i64) -> i64 { return nuc_mat_new(rows, cols); }
fn linalg_eye(n: i64) -> i64 { return nuc_mat_eye(n); }
fn linalg_free(h: i64) { nuc_mat_free(h); }
fn linalg_rows(h: i64) -> i64 { return nuc_mat_rows(h); }
fn linalg_cols(h: i64) -> i64 { return nuc_mat_cols(h); }
fn linalg_get(h: i64, r: i64, c: i64) -> i64 { return nuc_mat_get(h, r, c); }
fn linalg_set(h: i64, r: i64, c: i64, v: i64) { nuc_mat_set(h, r, c, v); }

fn linalg_add(a: i64, b: i64) -> i64 { return nuc_mat_add(a, b); }
fn linalg_sub(a: i64, b: i64) -> i64 { return nuc_mat_sub(a, b); }
fn linalg_scale(a: i64, s: i64) -> i64 { return nuc_mat_scale(a, s); }
fn linalg_mul(a: i64, b: i64) -> i64 { return nuc_mat_mul(a, b); }
fn linalg_transpose(h: i64) -> i64 { return nuc_mat_transpose(h); }
fn linalg_trace(h: i64) -> i64 { return nuc_mat_trace(h); }
fn linalg_norm(h: i64, kind: i64) -> i64 { return nuc_mat_norm(h, kind); }
fn linalg_det(h: i64) -> i64 { return nuc_mat_det(h); }
fn linalg_inv(h: i64) -> i64 { return nuc_mat_inv(h); }
fn linalg_rank(h: i64, tol: i64) -> i64 { return nuc_mat_rank(h, tol); }
fn linalg_solve(a: i64, b: i64) -> i64 { return nuc_mat_solve(a, b); }

// LU
fn linalg_lu(h: i64) -> i64 { return nuc_mat_lu(h); }
fn linalg_lu_L(h: i64) -> i64 { return nuc_mat_lu_L(h); }
fn linalg_lu_U(h: i64) -> i64 { return nuc_mat_lu_U(h); }
fn linalg_lu_P(h: i64) -> i64 { return nuc_mat_lu_P(h); }

// QR
fn linalg_qr(h: i64) -> i64 { return nuc_mat_qr(h); }
fn linalg_qr_Q(h: i64) -> i64 { return nuc_mat_qr_Q(h); }
fn linalg_qr_R(h: i64) -> i64 { return nuc_mat_qr_R(h); }

fn linalg_cholesky(h: i64) -> i64 { return nuc_mat_cholesky(h); }

// Eigen
fn linalg_eig(h: i64) -> i64 { return nuc_mat_eig(h); }
fn linalg_eig_vals(h: i64) -> i64 { return nuc_mat_eig_vals(h); }
fn linalg_eig_vecs(h: i64) -> i64 { return nuc_mat_eig_vecs(h); }

// SVD
fn linalg_svd(h: i64) -> i64 { return nuc_mat_svd(h); }
fn linalg_svd_U(h: i64) -> i64 { return nuc_mat_svd_U(h); }
fn linalg_svd_S(h: i64) -> i64 { return nuc_mat_svd_S(h); }
fn linalg_svd_V(h: i64) -> i64 { return nuc_mat_svd_V(h); }

// Ridge regression
fn linalg_ridge_solve(X: i64, y: i64, lambda: i64) -> i64 { return nuc_ridge_solve(X, y, lambda); }
fn linalg_ridge_predict(model: i64, X: i64) -> i64 { return nuc_ridge_predict(model, X); }
