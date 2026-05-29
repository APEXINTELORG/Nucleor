// rods/attention2 — Modern attention variants
//
//   - FlashAttention — tiled / online-softmax for long contexts
//     without materializing the full attention matrix.
//   - GQA (Grouped-Query Attention) — used in LLaMA 2/3, Mistral.
//     KV heads are shared across multiple Q heads.
//   - MLA (Multi-Head Latent Attention) — used in DeepSeek-V2/3.
//     Compress KV down to a low-rank latent and re-expand at use.
//   - Sliding-window — strict locality; each token attends only
//     to the previous W tokens.
//   - Differential — used in DiffTransformer; subtracts two
//     softmax-attention heads to reduce noise / hallucination.
//
// All tensor-shaped arguments are i64 handles to flat-allocated
// buffers; classic-style attention lives in `transformer.nr`.
//
// See `stdlib/runtime/attention2_rt.c`.
#cfile "../runtime/attention2_rt.c"

// v0.8.45 ML-1 fix: extern sig now matches C runtime 7-arg signature
// (seq_q, seq_k separately for cross-attention support). Pre-fix rod
// sig was 6 args while C took 7 — the C call read garbage from the
// uninitialized stack slot for block_size, producing silent miscompute
// on every flash-attention call.
extern fn nuc_attn_flash(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, d_k: i64, block_size: i64) -> i64;
// ML-1 sister fixes:
// gqa rod sig now matches C 8-arg sig (seq_q + seq_k split, head_dim
// instead of d_model). mla_compress / mla_decompress rod sigs now
// match C 4-arg sigs (the seq_len param was rod-side fiction; C never
// used it).
extern fn nuc_attn_gqa(Q_h: i64, K_h: i64, V_h: i64, seq_q: i64, seq_k: i64, head_dim: i64, n_q_heads: i64, n_kv_heads: i64) -> i64;
extern fn nuc_attn_mla_compress(hidden_h: i64, W_down_h: i64, d_model: i64, d_latent: i64) -> i64;
extern fn nuc_attn_mla_decompress(latent_h: i64, W_up_h: i64, d_latent: i64, d_out: i64) -> i64;
extern fn nuc_attn_sliding_window(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64, window: i64) -> i64;
extern fn nuc_attn_differential(Q_h: i64, K_h: i64, V_h: i64, seq_len: i64, d_k: i64, lambda_bits: i64) -> i64;

// Self-attention convenience wrapper — passes seq for both seq_q
// and seq_k. For cross-attention, call nuc_attn_flash directly with
// distinct seq_q / seq_k.
fn attn_flash(Q: i64, K: i64, V: i64, seq: i64, d_k: i64, block: i64) -> i64 {
    return nuc_attn_flash(Q, K, V, seq, seq, d_k, block);
}

// v0.8.45 ML-1 — explicit cross-attention variant exposing the
// distinct query/key sequence lengths from the C signature.
fn attn_flash_cross(Q: i64, K: i64, V: i64, seq_q: i64, seq_k: i64, d_k: i64, block: i64) -> i64 {
    return nuc_attn_flash(Q, K, V, seq_q, seq_k, d_k, block);
}
// Self-attention convenience wrapper for GQA. For cross-attention,
// call attn_gqa_cross with distinct seq_q/seq_k.
fn attn_gqa(Q: i64, K: i64, V: i64, seq: i64, head_dim: i64, n_q: i64, n_kv: i64) -> i64 {
    return nuc_attn_gqa(Q, K, V, seq, seq, head_dim, n_q, n_kv);
}
fn attn_gqa_cross(Q: i64, K: i64, V: i64, seq_q: i64, seq_k: i64, head_dim: i64, n_q: i64, n_kv: i64) -> i64 {
    return nuc_attn_gqa(Q, K, V, seq_q, seq_k, head_dim, n_q, n_kv);
}
// MLA: rod parameter `seq` was fiction — C runtime never used it.
// Drop the param. Callers using `seq` get a clean compile error and
// can remove the dead arg.
fn attn_mla_compress(h: i64, W_down: i64, d_model: i64, d_latent: i64) -> i64 {
    return nuc_attn_mla_compress(h, W_down, d_model, d_latent);
}
fn attn_mla_decompress(latent: i64, W_up: i64, d_latent: i64, d_out: i64) -> i64 {
    return nuc_attn_mla_decompress(latent, W_up, d_latent, d_out);
}
fn attn_sliding_window(Q: i64, K: i64, V: i64, seq: i64, d_k: i64, window: i64) -> i64 {
    return nuc_attn_sliding_window(Q, K, V, seq, d_k, window);
}
fn attn_differential(Q: i64, K: i64, V: i64, seq: i64, d_k: i64, lambda_bits: i64) -> i64 {
    return nuc_attn_differential(Q, K, V, seq, d_k, lambda_bits);
}
