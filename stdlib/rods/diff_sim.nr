// rods/diff_sim — Differentiable quantum simulation
//
// N-core (parallel circuit replicas), learnable noise logits per
// gate, von Neumann entropy backprop. The runtime supports forward
// state-vector evolution, adjoint-method backprop through gates,
// per-feature gradient extraction, gate-importance scoring, and
// import / export of learned noise priors.
//
// Modes encoded in `mode_bits`: bit 0 = noisy / clean, bit 1 =
// per-feature gradient, bit 2 = state-vector caching. See the
// runtime for the full enumeration.
//
// Float values cross the FFI as i64 reinterpreted bits
// (`*_bits` parameters).
//
// See `stdlib/runtime/diff_sim_rt.c`.
#cfile "../runtime/diff_sim_rt.c"

extern fn nuc_diff_sim_init(nq: i64, n_cores: i64, mode_bits: i64, seed: i64) -> i64;
extern fn nuc_diff_sim_init_from_prior(nq: i64, n_cores: i64, prior_vec: i64, seed: i64) -> i64;
extern fn nuc_diff_gate(handle: i64, gate_type: i64, q0: i64, q1: i64, angle_bits: i64);
extern fn nuc_diff_extract(handle: i64) -> i64;
extern fn nuc_diff_backward(handle: i64, grad_loss_bits: i64);
extern fn nuc_diff_backward_perfeature(handle: i64, grad_input_vec: i64);
extern fn nuc_diff_backward_selective(handle: i64, grad_loss_bits: i64, threshold_bits: i64);
extern fn nuc_diff_get_logits(handle: i64) -> i64;
extern fn nuc_diff_get_grad_logits(handle: i64) -> i64;
extern fn nuc_diff_set_logits(handle: i64, vec: i64);
extern fn nuc_diff_zero_grad(handle: i64);
extern fn nuc_diff_reset(handle: i64);
extern fn nuc_diff_reset_cached(handle: i64) -> i64;
extern fn nuc_diff_cache_clean(handle: i64);
extern fn nuc_diff_resize_cores(handle: i64, new_n_cores: i64) -> i64;
extern fn nuc_diff_n_gates(handle: i64) -> i64;
extern fn nuc_diff_n_noisy(handle: i64) -> i64;
extern fn nuc_diff_logit_count(handle: i64) -> i64;
extern fn nuc_diff_gate_importance(handle: i64) -> i64;
extern fn nuc_diff_export_prior(handle: i64) -> i64;
extern fn nuc_diff_get_sv(handle: i64, core: i64) -> i64;
extern fn nuc_diff_get_probs(handle: i64, core: i64) -> i64;
extern fn nuc_diff_free(handle: i64);

fn diff_sim_init(nq: i64, n_cores: i64, mode_bits: i64, seed: i64) -> i64 {
    return nuc_diff_sim_init(nq, n_cores, mode_bits, seed);
}
fn diff_sim_init_from_prior(nq: i64, n_cores: i64, prior_vec: i64, seed: i64) -> i64 {
    return nuc_diff_sim_init_from_prior(nq, n_cores, prior_vec, seed);
}
fn diff_gate(h: i64, gate_type: i64, q0: i64, q1: i64, angle_bits: i64) {
    nuc_diff_gate(h, gate_type, q0, q1, angle_bits);
}
fn diff_extract(h: i64) -> i64 { return nuc_diff_extract(h); }
fn diff_backward(h: i64, grad_loss_bits: i64) {
    nuc_diff_backward(h, grad_loss_bits);
}
fn diff_backward_perfeature(h: i64, grad_input_vec: i64) {
    nuc_diff_backward_perfeature(h, grad_input_vec);
}
fn diff_backward_selective(h: i64, grad_loss_bits: i64, threshold_bits: i64) {
    nuc_diff_backward_selective(h, grad_loss_bits, threshold_bits);
}
fn diff_get_logits(h: i64) -> i64 { return nuc_diff_get_logits(h); }
fn diff_get_grad_logits(h: i64) -> i64 { return nuc_diff_get_grad_logits(h); }
fn diff_set_logits(h: i64, v: i64) { nuc_diff_set_logits(h, v); }
fn diff_zero_grad(h: i64) { nuc_diff_zero_grad(h); }
fn diff_reset(h: i64) { nuc_diff_reset(h); }
fn diff_reset_cached(h: i64) -> i64 { return nuc_diff_reset_cached(h); }
fn diff_cache_clean(h: i64) { nuc_diff_cache_clean(h); }
fn diff_resize_cores(h: i64, n: i64) -> i64 { return nuc_diff_resize_cores(h, n); }
fn diff_n_gates(h: i64) -> i64 { return nuc_diff_n_gates(h); }
fn diff_n_noisy(h: i64) -> i64 { return nuc_diff_n_noisy(h); }
fn diff_logit_count(h: i64) -> i64 { return nuc_diff_logit_count(h); }
fn diff_gate_importance(h: i64) -> i64 { return nuc_diff_gate_importance(h); }
fn diff_export_prior(h: i64) -> i64 { return nuc_diff_export_prior(h); }
fn diff_get_sv(h: i64, core: i64) -> i64 { return nuc_diff_get_sv(h, core); }
fn diff_get_probs(h: i64, core: i64) -> i64 { return nuc_diff_get_probs(h, core); }
fn diff_free(h: i64) { nuc_diff_free(h); }
