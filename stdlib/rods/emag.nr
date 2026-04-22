// =====================================================
// rods/emag — FDTD Electromagnetics
// =====================================================
// Import: import "stdlib/rods/emag.nr"
// Provides: 2D FDTD with materials, sources, Ez/Hx/Hy field
//   accessors, energy integration. Yee-grid solver.
// =====================================================

#cfile "../runtime/emag_rt.c"

extern fn nuc_em_new_2d(Nx: i64, Ny: i64, dx: i64, dt: i64) -> i64;
extern fn nuc_em_set_material(h: i64, x0: i64, y0: i64, x1: i64, y1: i64, eps_r: i64, sigma: i64);
extern fn nuc_em_set_source(h: i64, x: i64, y: i64, freq: i64, amp: i64);
extern fn nuc_em_step(h: i64);
extern fn nuc_em_get_Ez(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_em_get_Hx(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_em_get_Hy(h: i64, x: i64, y: i64) -> i64;
extern fn nuc_em_energy(h: i64) -> i64;
extern fn nuc_em_free(h: i64);

fn em_new_2d(Nx: i64, Ny: i64, dx: i64, dt: i64) -> i64 { return nuc_em_new_2d(Nx, Ny, dx, dt); }
fn em_set_material(h: i64, x0: i64, y0: i64, x1: i64, y1: i64, eps_r: i64, sigma: i64) {
    nuc_em_set_material(h, x0, y0, x1, y1, eps_r, sigma);
}
fn em_set_source(h: i64, x: i64, y: i64, freq: i64, amp: i64) {
    nuc_em_set_source(h, x, y, freq, amp);
}
fn em_step(h: i64) { nuc_em_step(h); }
fn em_get_Ez(h: i64, x: i64, y: i64) -> i64 { return nuc_em_get_Ez(h, x, y); }
fn em_get_Hx(h: i64, x: i64, y: i64) -> i64 { return nuc_em_get_Hx(h, x, y); }
fn em_get_Hy(h: i64, x: i64, y: i64) -> i64 { return nuc_em_get_Hy(h, x, y); }
fn em_energy(h: i64) -> i64 { return nuc_em_energy(h); }
fn em_free(h: i64) { nuc_em_free(h); }
