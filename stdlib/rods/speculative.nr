// rods/speculative — Speculative decoding for LLM inference
#cfile "../runtime/speculative_rt.c"

extern fn nuc_spec_seed(seed: i64);
extern fn nuc_spec_verify(draft_probs: i64, target_probs: i64, draft_tokens: i64, n_draft: i64, vocab: i64) -> i64;
extern fn nuc_spec_build_tree(topk_tokens: i64, topk_probs: i64, max_depth: i64, k: i64, max_nodes: i64) -> i64;
extern fn nuc_spec_tree_mask(parents: i64, n_nodes: i64) -> i64;
extern fn nuc_spec_sample(logits: i64, temperature: i64, top_k: i64) -> i64;

fn spec_seed(s: i64) { nuc_spec_seed(s); }
fn spec_verify(draft: i64, target: i64, tokens: i64, n: i64, vocab: i64) -> i64 {
    return nuc_spec_verify(draft, target, tokens, n, vocab);
}
fn spec_build_tree(tokens: i64, probs: i64, depth: i64, k: i64, max_nodes: i64) -> i64 {
    return nuc_spec_build_tree(tokens, probs, depth, k, max_nodes);
}
fn spec_tree_mask(parents: i64, n: i64) -> i64 { return nuc_spec_tree_mask(parents, n); }
fn spec_sample(logits: i64, temp: i64, top_k: i64) -> i64 { return nuc_spec_sample(logits, temp, top_k); }
