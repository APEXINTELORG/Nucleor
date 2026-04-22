// =====================================================
// rods/thermo — Heat Transfer and Thermodynamics
// =====================================================
// Import: import "stdlib/rods/thermo.nr"
// Provides: 2D heat equation (explicit and steady-state),
//   ideal gas law, Carnot efficiency, blackbody radiation.
// =====================================================

#cfile "../runtime/thermo_rt.c"

extern fn nuc_heat_2d(T: i64, k: i64, rho_cp: i64, dx: i64, dt: i64, N: i64) -> i64;
extern fn nuc_heat_steady_state(T: i64, source: i64, k: i64, dx: i64, N: i64, tol: i64) -> i64;
extern fn nuc_thermo_ideal_gas(P: i64, V: i64, n: i64, T: i64) -> i64;
extern fn nuc_thermo_carnot_eff(Th: i64, Tc: i64) -> i64;
extern fn nuc_thermo_radiation(T: i64, emissivity: i64, area: i64) -> i64;

fn heat_2d_step(T: i64, k: i64, rho_cp: i64, dx: i64, dt: i64, N: i64) -> i64 { return nuc_heat_2d(T, k, rho_cp, dx, dt, N); }
fn heat_steady_state(T: i64, source: i64, k: i64, dx: i64, N: i64, tol: i64) -> i64 { return nuc_heat_steady_state(T, source, k, dx, N, tol); }
fn thermo_ideal_gas(P: i64, V: i64, n: i64, T: i64) -> i64 { return nuc_thermo_ideal_gas(P, V, n, T); }
fn thermo_carnot(Th: i64, Tc: i64) -> i64 { return nuc_thermo_carnot_eff(Th, Tc); }
fn thermo_radiation(T: i64, emissivity: i64, area: i64) -> i64 { return nuc_thermo_radiation(T, emissivity, area); }
