// rods/scan — Parallel-scan / prefix-sum / SSM kernels
#cfile "../runtime/scan_rt.c"

extern fn nuc_scan_prefix_sum(v: i64) -> i64;
extern fn nuc_scan_prefix_sum_exclusive(v: i64) -> i64;
extern fn nuc_scan_prefix_prod(v: i64) -> i64;
extern fn nuc_scan_prefix_max(v: i64) -> i64;
extern fn nuc_scan_associative_linear(a: i64, b: i64) -> i64;
extern fn nuc_scan_segmented_sum(v: i64, flags: i64) -> i64;
extern fn nuc_scan_cumulative_logsumexp(v: i64) -> i64;
extern fn nuc_scan_ssm(decay: i64, input: i64, L: i64, N: i64) -> i64;

fn scan_sum(v: i64) -> i64 { return nuc_scan_prefix_sum(v); }
fn scan_sum_exclusive(v: i64) -> i64 { return nuc_scan_prefix_sum_exclusive(v); }
fn scan_prod(v: i64) -> i64 { return nuc_scan_prefix_prod(v); }
fn scan_max(v: i64) -> i64 { return nuc_scan_prefix_max(v); }
fn scan_associative(a: i64, b: i64) -> i64 { return nuc_scan_associative_linear(a, b); }
fn scan_seg_sum(v: i64, flags: i64) -> i64 { return nuc_scan_segmented_sum(v, flags); }
fn scan_logsumexp(v: i64) -> i64 { return nuc_scan_cumulative_logsumexp(v); }
fn scan_ssm(decay: i64, input: i64, L: i64, N: i64) -> i64 { return nuc_scan_ssm(decay, input, L, N); }
