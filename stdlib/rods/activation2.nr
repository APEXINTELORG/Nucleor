// rods/activation2 — Modern transformer activations + normalizations
//
// SwiGLU (used in LLaMA 2/3, Gemma), GeGLU (PaLM), GELU, SiLU,
// JumpReLU (interpretability literature), DyT, RMSNorm (LLaMA), QK-Norm (used
// in many recent models), DeepNorm (DeepSpeed), RoPE (rotary
// positional embedding, single-step + sequence variants), softmax,
// sigmoid. All operate on i64 vec handles holding f64 bits.
//
// `*_bits` parameters take f64 reinterpreted as i64 — convert at
// the call site with the standard f64-bits builtins.
//
// The activations live in their own rod (rather than `nn`) because
// they're the primitives the user-facing transformer rod composes —
// keeping them separate lets users build custom architectures.
//
// See `stdlib/runtime/activation2_rt.c`.
#cfile "../runtime/activation2_rt.c"

extern fn nuc_act_gelu(vh: i64) -> i64;
extern fn nuc_act_silu(vh: i64) -> i64;
extern fn nuc_act_swiglu(gate_h: i64, value_h: i64) -> i64;
extern fn nuc_act_geglu(gate_h: i64, value_h: i64) -> i64;
extern fn nuc_act_jumprelu(vh: i64, theta_bits: i64) -> i64;
extern fn nuc_act_dyt(vh: i64, alpha_bits: i64) -> i64;
extern fn nuc_norm_rms(vh: i64, gamma_h: i64) -> i64;
extern fn nuc_norm_qk(qk_h: i64, head_dim: i64) -> i64;
extern fn nuc_rope_apply(vh: i64, pos: i64, head_dim: i64) -> i64;
extern fn nuc_rope_apply_seq(vh: i64, seq_len: i64, head_dim: i64, n_heads: i64) -> i64;
extern fn nuc_norm_deep(x_h: i64, sublayer_h: i64, alpha_bits: i64) -> i64;
extern fn nuc_act_softmax(vh: i64) -> i64;
extern fn nuc_act_sigmoid(vh: i64) -> i64;

fn act_gelu(v: i64) -> i64 { return nuc_act_gelu(v); }
fn act_silu(v: i64) -> i64 { return nuc_act_silu(v); }
fn act_swiglu(gate: i64, value: i64) -> i64 { return nuc_act_swiglu(gate, value); }
fn act_geglu(gate: i64, value: i64) -> i64 { return nuc_act_geglu(gate, value); }
fn act_jumprelu(v: i64, theta_bits: i64) -> i64 { return nuc_act_jumprelu(v, theta_bits); }
fn act_dyt(v: i64, alpha_bits: i64) -> i64 { return nuc_act_dyt(v, alpha_bits); }
fn norm_rms(v: i64, gamma: i64) -> i64 { return nuc_norm_rms(v, gamma); }
fn norm_qk(qk: i64, head_dim: i64) -> i64 { return nuc_norm_qk(qk, head_dim); }
fn rope_apply(v: i64, pos: i64, head_dim: i64) -> i64 {
    return nuc_rope_apply(v, pos, head_dim);
}
fn rope_apply_seq(v: i64, seq_len: i64, head_dim: i64, n_heads: i64) -> i64 {
    return nuc_rope_apply_seq(v, seq_len, head_dim, n_heads);
}
fn norm_deep(x: i64, sublayer: i64, alpha_bits: i64) -> i64 {
    return nuc_norm_deep(x, sublayer, alpha_bits);
}
fn act_softmax(v: i64) -> i64 { return nuc_act_softmax(v); }
fn act_sigmoid(v: i64) -> i64 { return nuc_act_sigmoid(v); }
