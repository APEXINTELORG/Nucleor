// =====================================================
// rods/stats — Statistics and Probability
// =====================================================
// Import: import "stdlib/rods/stats.nr"
// Provides: mean / median / variance / stddev, covariance,
//   correlation, percentile, histogram, linear regression
//   (slope/intercept/R²), t-test, chi-square, kernel density
//   estimation.
// =====================================================

#cfile "../runtime/stats_rt.c"

extern fn nuc_stat_mean(v: i64) -> i64;
extern fn nuc_stat_median(v: i64) -> i64;
extern fn nuc_stat_var(v: i64) -> i64;
extern fn nuc_stat_std(v: i64) -> i64;
extern fn nuc_stat_cov(x: i64, y: i64) -> i64;
extern fn nuc_stat_corr(x: i64, y: i64) -> i64;
extern fn nuc_stat_percentile(v: i64, p: i64) -> i64;
extern fn nuc_stat_histogram(v: i64, bins: i64) -> i64;
extern fn nuc_stat_linreg(x: i64, y: i64) -> i64;
extern fn nuc_stat_linreg_slope(h: i64) -> i64;
extern fn nuc_stat_linreg_intercept(h: i64) -> i64;
extern fn nuc_stat_linreg_r2(h: i64) -> i64;
extern fn nuc_stat_ttest(a: i64, b: i64) -> i64;
extern fn nuc_stat_ttest_t(h: i64) -> i64;
extern fn nuc_stat_ttest_p(h: i64) -> i64;
extern fn nuc_stat_chi2(obs: i64, exp: i64) -> i64;
extern fn nuc_stat_kde(v: i64, x: i64) -> i64;

fn stat_mean(v: i64) -> i64 { return nuc_stat_mean(v); }
fn stat_median(v: i64) -> i64 { return nuc_stat_median(v); }
fn stat_var(v: i64) -> i64 { return nuc_stat_var(v); }
fn stat_std(v: i64) -> i64 { return nuc_stat_std(v); }
fn stat_cov(x: i64, y: i64) -> i64 { return nuc_stat_cov(x, y); }
fn stat_corr(x: i64, y: i64) -> i64 { return nuc_stat_corr(x, y); }
fn stat_percentile(v: i64, p: i64) -> i64 { return nuc_stat_percentile(v, p); }
fn stat_histogram(v: i64, bins: i64) -> i64 { return nuc_stat_histogram(v, bins); }
fn stat_linreg(x: i64, y: i64) -> i64 { return nuc_stat_linreg(x, y); }
fn stat_linreg_slope(h: i64) -> i64 { return nuc_stat_linreg_slope(h); }
fn stat_linreg_intercept(h: i64) -> i64 { return nuc_stat_linreg_intercept(h); }
fn stat_linreg_r2(h: i64) -> i64 { return nuc_stat_linreg_r2(h); }
fn stat_ttest(a: i64, b: i64) -> i64 { return nuc_stat_ttest(a, b); }
fn stat_ttest_t(h: i64) -> i64 { return nuc_stat_ttest_t(h); }
fn stat_ttest_p(h: i64) -> i64 { return nuc_stat_ttest_p(h); }
fn stat_chi2(obs: i64, exp: i64) -> i64 { return nuc_stat_chi2(obs, exp); }
fn stat_kde(v: i64, x: i64) -> i64 { return nuc_stat_kde(v, x); }
