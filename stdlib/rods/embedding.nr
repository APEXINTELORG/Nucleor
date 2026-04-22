// =====================================================
// rods/embedding — Vector embedding tables
// =====================================================

#cfile "../runtime/embedding_rt.c"

extern fn nuc_emb_new(vocab_size: i64, dim: i64) -> i64;
extern fn nuc_emb_lookup(eh: i64, token_id: i64) -> i64;
extern fn nuc_emb_set(eh: i64, token_id: i64, vec: i64);
extern fn nuc_emb_cosine_sim(a: i64, b: i64) -> i64;
extern fn nuc_emb_dot(a: i64, b: i64) -> i64;
extern fn nuc_emb_nearest(eh: i64, query: i64, k: i64) -> i64;
extern fn nuc_emb_normalize(v: i64) -> i64;
extern fn nuc_emb_free(eh: i64);

fn emb_new(vocab: i64, dim: i64) -> i64 { return nuc_emb_new(vocab, dim); }
fn emb_lookup(eh: i64, token_id: i64) -> i64 { return nuc_emb_lookup(eh, token_id); }
fn emb_set(eh: i64, token_id: i64, vec: i64) { nuc_emb_set(eh, token_id, vec); }
fn emb_cosine(a: i64, b: i64) -> i64 { return nuc_emb_cosine_sim(a, b); }
fn emb_dot(a: i64, b: i64) -> i64 { return nuc_emb_dot(a, b); }
fn emb_nearest(eh: i64, query: i64, k: i64) -> i64 { return nuc_emb_nearest(eh, query, k); }
fn emb_normalize(v: i64) -> i64 { return nuc_emb_normalize(v); }
fn emb_free(eh: i64) { nuc_emb_free(eh); }
