// =====================================================
// rods/pca — Principal Component Analysis
// =====================================================
// Import: import "stdlib/rods/pca.nr"
// Provides: fit, project a sample onto the top-k components,
//   per-component variance ratio, eigenvalue accessor.
// =====================================================

#cfile "../runtime/pca_rt.c"

extern fn nuc_pca_fit(X: i64, n_samples: i64, n_features: i64) -> i64;
extern fn nuc_pca_project(pca: i64, sample: i64, k: i64) -> i64;
extern fn nuc_pca_variance_ratio(pca: i64, k: i64) -> i64;
extern fn nuc_pca_eigenvalue(pca: i64, k: i64) -> i64;
extern fn nuc_pca_free(pca: i64);

fn pca_fit(X: i64, n_samples: i64, n_features: i64) -> i64 { return nuc_pca_fit(X, n_samples, n_features); }
fn pca_project(pca: i64, sample: i64, k: i64) -> i64 { return nuc_pca_project(pca, sample, k); }
fn pca_variance_ratio(pca: i64, k: i64) -> i64 { return nuc_pca_variance_ratio(pca, k); }
fn pca_eigenvalue(pca: i64, k: i64) -> i64 { return nuc_pca_eigenvalue(pca, k); }
fn pca_free(pca: i64) { nuc_pca_free(pca); }
