// =====================================================
// rods/pq — Product Quantization (compressed vector search)
// =====================================================

#cfile "../runtime/pq_rt.c"

extern fn nuc_pq_train(data: i64, n_vec: i64, dim: i64, n_subspaces: i64, n_centroids: i64) -> i64;
extern fn nuc_pq_encode(pq: i64, vec: i64) -> i64;
extern fn nuc_pq_distance_table(pq: i64, query: i64) -> i64;
extern fn nuc_pq_adc(table: i64, codes: i64, n_subspaces: i64) -> i64;
extern fn nuc_pq_search(pq: i64, query: i64, db_codes: i64, n_vec: i64, k: i64) -> i64;
extern fn nuc_pq_free(pq: i64);

fn pq_train(data: i64, n_vec: i64, dim: i64, n_sub: i64, n_centroids: i64) -> i64 {
    return nuc_pq_train(data, n_vec, dim, n_sub, n_centroids);
}
fn pq_encode(pq: i64, vec: i64) -> i64 { return nuc_pq_encode(pq, vec); }
fn pq_dist_table(pq: i64, query: i64) -> i64 { return nuc_pq_distance_table(pq, query); }
fn pq_adc(table: i64, codes: i64, n_sub: i64) -> i64 { return nuc_pq_adc(table, codes, n_sub); }
fn pq_search(pq: i64, query: i64, db: i64, n_vec: i64, k: i64) -> i64 {
    return nuc_pq_search(pq, query, db, n_vec, k);
}
fn pq_free(pq: i64) { nuc_pq_free(pq); }
