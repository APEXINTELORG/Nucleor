// =====================================================
// rods/sparse — Sparse Matrix Operations (CSR Format)
// =====================================================
// Import: import "stdlib/rods/sparse.nr"
// Provides: CSR construction (from COO or dense), accessors,
//   sparse mat-vec, transpose, conjugate gradient + GMRES solvers.
// =====================================================

#cfile "../runtime/sparse_rt.c"

extern fn nuc_sp_new_csr(rows: i64, cols: i64, nnz: i64) -> i64;
extern fn nuc_sp_from_coo(row_vec: i64, col_vec: i64, val_vec: i64, rows: i64, cols: i64, nnz: i64) -> i64;
extern fn nuc_sp_from_dense(mh: i64) -> i64;
extern fn nuc_sp_set(h: i64, r: i64, c: i64, val: i64);
extern fn nuc_sp_get(h: i64, r: i64, c: i64) -> i64;
extern fn nuc_sp_rows(h: i64) -> i64;
extern fn nuc_sp_cols(h: i64) -> i64;
extern fn nuc_sp_nnz(h: i64) -> i64;
extern fn nuc_sp_mul_vec(a: i64, x: i64) -> i64;
extern fn nuc_sp_cg_solve(a: i64, b: i64, tol: i64) -> i64;
extern fn nuc_sp_gmres(a: i64, b: i64, tol: i64) -> i64;
extern fn nuc_sp_transpose(a: i64) -> i64;
extern fn nuc_sp_free(h: i64);

fn sparse_new_csr(rows: i64, cols: i64, nnz: i64) -> i64 { return nuc_sp_new_csr(rows, cols, nnz); }
fn sparse_from_coo(row_v: i64, col_v: i64, val_v: i64, rows: i64, cols: i64, nnz: i64) -> i64 { return nuc_sp_from_coo(row_v, col_v, val_v, rows, cols, nnz); }
fn sparse_from_dense(m: i64) -> i64 { return nuc_sp_from_dense(m); }
fn sparse_set(h: i64, r: i64, c: i64, v: i64) { nuc_sp_set(h, r, c, v); }
fn sparse_get(h: i64, r: i64, c: i64) -> i64 { return nuc_sp_get(h, r, c); }
fn sparse_rows(h: i64) -> i64 { return nuc_sp_rows(h); }
fn sparse_cols(h: i64) -> i64 { return nuc_sp_cols(h); }
fn sparse_nnz(h: i64) -> i64 { return nuc_sp_nnz(h); }
fn sparse_mul_vec(a: i64, x: i64) -> i64 { return nuc_sp_mul_vec(a, x); }
fn sparse_cg_solve(a: i64, b: i64, tol: i64) -> i64 { return nuc_sp_cg_solve(a, b, tol); }
fn sparse_gmres(a: i64, b: i64, tol: i64) -> i64 { return nuc_sp_gmres(a, b, tol); }
fn sparse_transpose(a: i64) -> i64 { return nuc_sp_transpose(a); }
fn sparse_free(h: i64) { nuc_sp_free(h); }
