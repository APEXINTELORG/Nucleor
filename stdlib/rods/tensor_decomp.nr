// =====================================================
// rods/tensor_decomp — Tensor Decompositions
// =====================================================
// Import: import "stdlib/rods/tensor_decomp.nr"
// Provides: CP-ALS (Canonical Polyadic / PARAFAC), Tensor-Train SVD
//   (3D), Kronecker product, Khatri-Rao product. Inputs are matrix
//   handles from rods/linalg.nr or rods/tensor_nd.nr.
// =====================================================

#cfile "../runtime/tensor_decomp_rt.c"

extern fn nuc_td_cp_als(X: i64, I: i64, J: i64, K: i64, R: i64, max_iter: i64) -> i64;
extern fn nuc_td_tt_svd_3d(X: i64, n1: i64, n2: i64, n3: i64, r1: i64, r2: i64) -> i64;
extern fn nuc_td_kronecker(A: i64, B: i64, am: i64, an: i64, bm: i64, bn: i64) -> i64;
extern fn nuc_td_khatri_rao(A: i64, B: i64, I: i64, J: i64, R: i64) -> i64;

fn tdecomp_cp_als(X: i64, I: i64, J: i64, K: i64, rank: i64, max_iter: i64) -> i64 {
    return nuc_td_cp_als(X, I, J, K, rank, max_iter);
}

fn tdecomp_tt_svd_3d(X: i64, n1: i64, n2: i64, n3: i64, r1: i64, r2: i64) -> i64 {
    return nuc_td_tt_svd_3d(X, n1, n2, n3, r1, r2);
}

fn tdecomp_kronecker(A: i64, B: i64, am: i64, an: i64, bm: i64, bn: i64) -> i64 {
    return nuc_td_kronecker(A, B, am, an, bm, bn);
}

fn tdecomp_khatri_rao(A: i64, B: i64, I: i64, J: i64, R: i64) -> i64 {
    return nuc_td_khatri_rao(A, B, I, J, R);
}
