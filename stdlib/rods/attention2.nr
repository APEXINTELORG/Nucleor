// rods/attention2 — Modern attention variants
//
//   - **FlashAttention** — tiled / online-softmax for long contexts
//     without materializing the full attention matrix.
//   - **GQA** (Grouped-Query Attention) — used in LLaMA 2/3, Mistral.
//     KV heads are shared across multiple Q heads.
//   - **MLA** (Multi-Head Latent Attention) — used in DeepSeek-V2/3.
//     Compress KV down to a low-rank latent and re-expand at use.
//   - **Sliding-window** — strict locality; each token attends only
//     to the previous W tokens.
//   - **Differential** — used in DiffTransformer; subtracts two
//     softmax-attention heads to reduce noise / hallucination.
//
// All tensor-shaped arguments are i64 handles to flat-allocated
// buffers; classic-style attention lives in `transformer.nr`.
//
// See `stdlib/runtime/attention2_rt.c`.
#cfile "../runtime/attention2_rt.c"

extern fn nuc_attn_flash(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64, block_size: i64) -> i64;
extern fn nuc_attn_gqa(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_model: i64, n_q_heads: i64, n_kv_heads: i64) -> i64;
extern fn nuc_attn_mla_compress(hidden_h: i64, W_down_h: i64, seq_len: i64, d_model: i64, d_latent: i64) -> i64;
extern fn nuc_attn_mla_decompress(latent_h: i64, W_up_h: i64, seq_len: i64, d_latent: i64, d_model: i64) -> i64;
extern fn nuc_attn_sliding_window(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64, window: i64) -> i64;
extern fn nuc_attn_differential(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64, lambda_bits: i64) -> i64;

fn attn_flash(Q: i64, K: i64, V: i64, seq: i64, d_k: i64, block: i64) -> i64 {
    return nuc_attn_flash(Q, K, V, seq, d_k, block);
}
fn attn_gqa(Q: i64, K: i64, V: i64, seq: i64, d_model: i64, n_q: i64, n_kv: i64) -> i64 {
    return nuc_attn_gqa(Q, K, V, seq, d_model, n_q, n_kv);
}
fn attn_mla_compress(h: i64, W_down: i64, seq: i64, d_model: i64, d_latent: i64) -> i64 {
    return nuc_attn_mla_compress(h, W_down, seq, d_model, d_latent);
}
fn attn_mla_decompress(latent: i64, W_up: i64, seq: i64, d_latent: i64, d_model: i64) -> i64 {
    return nuc_attn_mla_decompress(latent, W_up, seq, d_latent, d_model);
}
fn attn_sliding_window(Q: i64, K: i64, V: i64, seq: i64, d_k: i64, window: i64) -> i64 {
    return nuc_attn_sliding_window(Q, K, V, seq, d_k, window);
}
fn attn_differential(Q: i64, K: i64, V: i64, seq: i64, d_k: i64, lambda_bits: i64) -> i64 {
    return nuc_attn_differential(Q, K, V, seq, d_k, lambda_bits);
}
