// =====================================================
// rods/fluid — Lattice Boltzmann Fluid Simulation
// =====================================================
// Import: import "stdlib/rods/fluid.nr"
// Provides: 2D LBM with obstacles, inlet velocity, density,
//   velocity field, vorticity. D2Q9 lattice under the hood.
// =====================================================

#cfile "../runtime/fluid_rt.c"

extern fn nuc_lbm_new_2d(Nx: i64, Ny: i64, viscosity: i64) -> i64;
extern fn nuc_lbm_set_obstacle(h: i64, x: i64, y: i64);
extern fn nuc_lbm_set_inlet(h: i64, velocity: i64);
extern fn nuc_lbm_step(h: i64);
extern fn nuc_lbm_get_density(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_lbm_get_vx(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_lbm_get_vy(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_lbm_get_vorticity(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_lbm_free(h: i64);

fn lbm_new_2d(Nx: i64, Ny: i64, viscosity: i64) -> i64 { return nuc_lbm_new_2d(Nx, Ny, viscosity); }
fn lbm_set_obstacle(h: i64, x: i64, y: i64) { nuc_lbm_set_obstacle(h, x, y); }
fn lbm_set_inlet(h: i64, vel: i64) { nuc_lbm_set_inlet(h, vel); }
fn lbm_step(h: i64) { nuc_lbm_step(h); }
fn lbm_get_density(h: i64, x: i64, y: i64) -> i64 { return nuc_lbm_get_density(h, x, y); }
fn lbm_get_vx(h: i64, x: i64, y: i64) -> i64 { return nuc_lbm_get_vx(h, x, y); }
fn lbm_get_vy(h: i64, x: i64, y: i64) -> i64 { return nuc_lbm_get_vy(h, x, y); }
fn lbm_get_vorticity(h: i64, x: i64, y: i64) -> i64 { return nuc_lbm_get_vorticity(h, x, y); }
fn lbm_free(h: i64) { nuc_lbm_free(h); }
