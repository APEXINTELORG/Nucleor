// rods/kv_cache — KV cache for LLM inference (paged, with eviction)
#cfile "../runtime/kv_cache_rt.c"

extern fn nuc_kv_cache_new(n_layers: i64, n_heads: i64, head_dim: i64, max_seq: i64) -> i64;
extern fn nuc_kv_cache_insert(ch: i64, layer: i64, head: i64, pos: i64, k_vec: i64, v_vec: i64);
extern fn nuc_kv_cache_get_k(ch: i64, layer: i64, head: i64, pos: i64) -> i64;
extern fn nuc_kv_cache_get_v(ch: i64, layer: i64, head: i64, pos: i64) -> i64;
extern fn nuc_kv_cache_get_k_range(ch: i64, layer: i64, head: i64, start_pos: i64, end_pos: i64) -> i64;
extern fn nuc_kv_cache_get_v_range(ch: i64, layer: i64, head: i64, start_pos: i64, end_pos: i64) -> i64;
extern fn nuc_kv_cache_seq_len(ch: i64) -> i64;
extern fn nuc_kv_cache_blocks_used(ch: i64) -> i64;
extern fn nuc_kv_cache_evict_before(ch: i64, pos: i64);
extern fn nuc_kv_cache_free(ch: i64);

fn kv_new(n_layers: i64, n_heads: i64, head_dim: i64, max_seq: i64) -> i64 {
    return nuc_kv_cache_new(n_layers, n_heads, head_dim, max_seq);
}
fn kv_insert(ch: i64, layer: i64, head: i64, pos: i64, k: i64, v: i64) {
    nuc_kv_cache_insert(ch, layer, head, pos, k, v);
}
fn kv_get_k(ch: i64, layer: i64, head: i64, pos: i64) -> i64 { return nuc_kv_cache_get_k(ch, layer, head, pos); }
fn kv_get_v(ch: i64, layer: i64, head: i64, pos: i64) -> i64 { return nuc_kv_cache_get_v(ch, layer, head, pos); }
fn kv_get_k_range(ch: i64, layer: i64, head: i64, start_pos: i64, end_pos: i64) -> i64 {
    return nuc_kv_cache_get_k_range(ch, layer, head, start_pos, end_pos);
}
fn kv_get_v_range(ch: i64, layer: i64, head: i64, start_pos: i64, end_pos: i64) -> i64 {
    return nuc_kv_cache_get_v_range(ch, layer, head, start_pos, end_pos);
}
fn kv_seq_len(ch: i64) -> i64 { return nuc_kv_cache_seq_len(ch); }
fn kv_blocks_used(ch: i64) -> i64 { return nuc_kv_cache_blocks_used(ch); }
fn kv_evict_before(ch: i64, pos: i64) { nuc_kv_cache_evict_before(ch, pos); }
fn kv_free(ch: i64) { nuc_kv_cache_free(ch); }
