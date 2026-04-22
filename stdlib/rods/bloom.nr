// =====================================================
// rods/bloom — Bloom filter + HyperLogLog
// =====================================================
// Import: import "stdlib/rods/bloom.nr"
// =====================================================

#cfile "../runtime/bloom_rt.c"

extern fn nuc_bloom_new(expected: i64, fp_rate: i64) -> i64;
extern fn nuc_bloom_add(h: i64, key: str);
extern fn nuc_bloom_contains(h: i64, key: str) -> i64;
extern fn nuc_bloom_count(h: i64) -> i64;
extern fn nuc_bloom_fp_rate(h: i64) -> i64;
extern fn nuc_bloom_free(h: i64);

extern fn nuc_hll_new(precision: i64) -> i64;
extern fn nuc_hll_add(h: i64, key: str);
extern fn nuc_hll_count(h: i64) -> i64;
extern fn nuc_hll_free(h: i64);

fn bloom_new(expected: i64, fp_rate: i64) -> i64 { return nuc_bloom_new(expected, fp_rate); }
fn bloom_add(h: i64, key: str) { nuc_bloom_add(h, key); }
fn bloom_contains(h: i64, key: str) -> i64 { return nuc_bloom_contains(h, key); }
fn bloom_count(h: i64) -> i64 { return nuc_bloom_count(h); }
fn bloom_fp_rate(h: i64) -> i64 { return nuc_bloom_fp_rate(h); }
fn bloom_free(h: i64) { nuc_bloom_free(h); }

fn hll_new(precision: i64) -> i64 { return nuc_hll_new(precision); }
fn hll_add(h: i64, key: str) { nuc_hll_add(h, key); }
fn hll_count(h: i64) -> i64 { return nuc_hll_count(h); }
fn hll_free(h: i64) { nuc_hll_free(h); }
