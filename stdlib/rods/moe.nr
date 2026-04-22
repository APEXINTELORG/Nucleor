// =====================================================
// rods/moe — Mixture of Experts Routing
// =====================================================
// Import: import "stdlib/rods/moe.nr"
// Provides: top-K gating, route indices/weights extraction,
//   expert dispatch + combine, load-balancing tracker.
// =====================================================

#cfile "../runtime/moe_rt.c"

extern fn nuc_moe_topk_gate(logits: i64, n_tokens: i64, n_experts: i64, K: i64) -> i64;
extern fn nuc_moe_route_indices(h: i64) -> i64;
extern fn nuc_moe_route_weights(h: i64) -> i64;
extern fn nuc_moe_dispatch(tokens: i64, indices: i64, n_tokens: i64, dim: i64, n_experts: i64, K: i64) -> i64;
extern fn nuc_moe_combine(expert_outputs: i64, indices: i64, weights: i64, n_tokens: i64, dim: i64, K: i64) -> i64;
extern fn nuc_moe_balance_new(n_experts: i64) -> i64;
extern fn nuc_moe_balance_update(lb: i64, indices: i64, n_tokens: i64, K: i64);
extern fn nuc_moe_balance_bias(lb: i64) -> i64;
extern fn nuc_moe_balance_cv(lb: i64) -> i64;

fn moe_topk_gate(logits: i64, n_tokens: i64, n_experts: i64, K: i64) -> i64 {
    return nuc_moe_topk_gate(logits, n_tokens, n_experts, K);
}
fn moe_route_indices(h: i64) -> i64 { return nuc_moe_route_indices(h); }
fn moe_route_weights(h: i64) -> i64 { return nuc_moe_route_weights(h); }
fn moe_dispatch(tokens: i64, indices: i64, n_tokens: i64, dim: i64, n_experts: i64, K: i64) -> i64 {
    return nuc_moe_dispatch(tokens, indices, n_tokens, dim, n_experts, K);
}
fn moe_combine(expert_out: i64, indices: i64, weights: i64, n_tokens: i64, dim: i64, K: i64) -> i64 {
    return nuc_moe_combine(expert_out, indices, weights, n_tokens, dim, K);
}
fn moe_balance_new(n_experts: i64) -> i64 { return nuc_moe_balance_new(n_experts); }
fn moe_balance_update(lb: i64, indices: i64, n_tokens: i64, K: i64) {
    nuc_moe_balance_update(lb, indices, n_tokens, K);
}
fn moe_balance_bias(lb: i64) -> i64 { return nuc_moe_balance_bias(lb); }
fn moe_balance_cv(lb: i64) -> i64 { return nuc_moe_balance_cv(lb); }
