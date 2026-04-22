// =====================================================
// rods/taylor — Validated Taylor Model ODE Integrator
// =====================================================
// Import: import "stdlib/rods/taylor.nr"
// Provides: rigorous validated time-stepping for the Boussinesq /
//   Navier-Stokes-class systems, with provable error bounds. Originally
//   built for global-existence research on the Boussinesq equations.
//
// Workflow:
//   tm_init(N, order)          allocate the model with N modes, order p
//   tm_set_nu(nu)              viscosity
//   tm_set_omega(i, j, val)    initial vorticity field
//   tm_set_theta(i, j, val)    initial temperature field
//   tm_step(h, poi)            advance one validated step
//   tm_get_max_width()         current maximum interval width (proof gauge)
//   tm_get_time()              accumulated time
//
// =====================================================

#cfile "../runtime/taylor_rt.c"

extern fn nuc_tm_set_fd_order(order: i64);
extern fn nuc_tm_set_dealias(on: i64);
extern fn nuc_tm_init(N: i64, order: i64) -> i64;
extern fn nuc_tm_set_poi(iters: i64);
extern fn nuc_tm_set_nu(nu: i64);
extern fn nuc_tm_set_omega(i: i64, j: i64, val: i64);
extern fn nuc_tm_set_theta(i: i64, j: i64, val: i64);
extern fn nuc_tm_step(h: i64, poi: i64) -> i64;
extern fn nuc_tm_step_mr(h: i64, poi: i64) -> i64;
extern fn nuc_tm_step_signed(h: i64, poi: i64) -> i64;
extern fn nuc_tm_spectral_check() -> i64;
extern fn nuc_tm_get_D4() -> i64;
extern fn nuc_tm_get_spatial_err() -> i64;
extern fn nuc_tm_get_spectral_res() -> i64;
extern fn nuc_tm_tight_spatial_check() -> i64;
extern fn nuc_tm_get_tight_spatial_err() -> i64;
extern fn nuc_tm_compute_spatial_tau();
extern fn nuc_tm_disable_spatial_tau();
extern fn nuc_tm_get_omega_max_hi() -> i64;
extern fn nuc_tm_get_omega_max_lo() -> i64;
extern fn nuc_tm_get_max_width() -> i64;
extern fn nuc_tm_get_time() -> i64;
extern fn nuc_tm_get_steps() -> i64;
extern fn nuc_tm_get_radius() -> i64;
extern fn nuc_tm_get_theta_max_hi() -> i64;

fn tm_set_fd_order(order: i64) { nuc_tm_set_fd_order(order); }
fn tm_set_dealias(on: i64) { nuc_tm_set_dealias(on); }
fn tm_init(N: i64, order: i64) -> i64 { return nuc_tm_init(N, order); }
fn tm_set_poi(iters: i64) { nuc_tm_set_poi(iters); }
fn tm_set_nu(nu: i64) { nuc_tm_set_nu(nu); }
fn tm_set_omega(i: i64, j: i64, val: i64) { nuc_tm_set_omega(i, j, val); }
fn tm_set_theta(i: i64, j: i64, val: i64) { nuc_tm_set_theta(i, j, val); }
fn tm_step(h: i64, poi: i64) -> i64 { return nuc_tm_step(h, poi); }
fn tm_step_mr(h: i64, poi: i64) -> i64 { return nuc_tm_step_mr(h, poi); }
fn tm_step_signed(h: i64, poi: i64) -> i64 { return nuc_tm_step_signed(h, poi); }
fn tm_spectral_check() -> i64 { return nuc_tm_spectral_check(); }
fn tm_get_D4() -> i64 { return nuc_tm_get_D4(); }
fn tm_get_spatial_err() -> i64 { return nuc_tm_get_spatial_err(); }
fn tm_get_spectral_res() -> i64 { return nuc_tm_get_spectral_res(); }
fn tm_get_max_width() -> i64 { return nuc_tm_get_max_width(); }
fn tm_get_time() -> i64 { return nuc_tm_get_time(); }
fn tm_get_steps() -> i64 { return nuc_tm_get_steps(); }
fn tm_get_radius() -> i64 { return nuc_tm_get_radius(); }
