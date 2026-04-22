// =====================================================
// rods/hnsw — HNSW vector index (approximate nearest neighbor)
// =====================================================

#cfile "../runtime/hnsw_rt.c"

extern fn nuc_hnsw_new(dim: i64, M: i64, ef_construct: i64) -> i64;
extern fn nuc_hnsw_insert(idx: i64, vec: i64, id: i64);
extern fn nuc_hnsw_search(idx: i64, query: i64, ef: i64, k: i64) -> i64;
extern fn nuc_hnsw_size(idx: i64) -> i64;
extern fn nuc_hnsw_free(idx: i64);

fn hnsw_new(dim: i64, M: i64, ef_construct: i64) -> i64 { return nuc_hnsw_new(dim, M, ef_construct); }
fn hnsw_insert(idx: i64, vec: i64, id: i64) { nuc_hnsw_insert(idx, vec, id); }
fn hnsw_search(idx: i64, query: i64, ef: i64, k: i64) -> i64 { return nuc_hnsw_search(idx, query, ef, k); }
fn hnsw_size(idx: i64) -> i64 { return nuc_hnsw_size(idx); }
fn hnsw_free(idx: i64) { nuc_hnsw_free(idx); }
