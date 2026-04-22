// rods/diffusion — Diffusion models / rectified flow / DDPM
#cfile "../runtime/diffusion_rt.c"

extern fn nuc_diff_linear_schedule(n_steps: i64, beta_start: i64, beta_end: i64) -> i64;
extern fn nuc_diff_cosine_schedule(n_steps: i64) -> i64;
extern fn nuc_diff_forward(x0: i64, noise: i64, sqrt_ab: i64, sqrt_one_minus_ab: i64) -> i64;
extern fn nuc_diff_rectified_flow_interp(x0: i64, x1: i64, t: i64) -> i64;
extern fn nuc_diff_rectified_flow_target(x0: i64, x1: i64) -> i64;
extern fn nuc_diff_euler_step(xt: i64, velocity: i64, dt: i64) -> i64;
extern fn nuc_diff_timestep_embed(t: i64, dim: i64) -> i64;
extern fn nuc_diff_adaln(x: i64, scale: i64, shift: i64) -> i64;
extern fn nuc_diff_cfg(cond: i64, uncond: i64, scale: i64) -> i64;
extern fn nuc_diff_ddpm_reverse_step(xt: i64, pred_noise: i64, beta: i64, alpha: i64, alpha_bar: i64, noise: i64) -> i64;

fn diff_linear_schedule(n: i64, b0: i64, b1: i64) -> i64 { return nuc_diff_linear_schedule(n, b0, b1); }
fn diff_cosine_schedule(n: i64) -> i64 { return nuc_diff_cosine_schedule(n); }
fn diff_forward(x0: i64, noise: i64, sqrt_ab: i64, sqrt_one_minus_ab: i64) -> i64 {
    return nuc_diff_forward(x0, noise, sqrt_ab, sqrt_one_minus_ab);
}
fn diff_rf_interp(x0: i64, x1: i64, t: i64) -> i64 { return nuc_diff_rectified_flow_interp(x0, x1, t); }
fn diff_rf_target(x0: i64, x1: i64) -> i64 { return nuc_diff_rectified_flow_target(x0, x1); }
fn diff_euler_step(xt: i64, vel: i64, dt: i64) -> i64 { return nuc_diff_euler_step(xt, vel, dt); }
fn diff_timestep_embed(t: i64, dim: i64) -> i64 { return nuc_diff_timestep_embed(t, dim); }
fn diff_adaln(x: i64, scale: i64, shift: i64) -> i64 { return nuc_diff_adaln(x, scale, shift); }
fn diff_cfg(cond: i64, uncond: i64, scale: i64) -> i64 { return nuc_diff_cfg(cond, uncond, scale); }
fn diff_ddpm_step(xt: i64, pred: i64, beta: i64, alpha: i64, ab: i64, noise: i64) -> i64 {
    return nuc_diff_ddpm_reverse_step(xt, pred, beta, alpha, ab, noise);
}
