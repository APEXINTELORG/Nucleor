// =====================================================
// rods/physics — CODATA 2018 Physical Constants
// =====================================================
// Import: import "stdlib/rods/physics.nr"
// All values are returned as f64 bitcast to i64 (use rods/complex.nr
// f64_* helpers to do arithmetic with them).
// =====================================================

#cfile "../runtime/physics_const_rt.c"

// --- Fundamental constants (SI units) ---
extern fn nuc_const_c() -> i64;       // speed of light, m/s
extern fn nuc_const_h() -> i64;       // Planck constant, J·s
extern fn nuc_const_hbar() -> i64;    // reduced Planck, J·s
extern fn nuc_const_kb() -> i64;      // Boltzmann, J/K
extern fn nuc_const_e() -> i64;       // elementary charge, C
extern fn nuc_const_me() -> i64;      // electron mass, kg
extern fn nuc_const_mp() -> i64;      // proton mass, kg
extern fn nuc_const_mn() -> i64;      // neutron mass, kg
extern fn nuc_const_G() -> i64;       // gravitational, N·m²/kg²
extern fn nuc_const_Na() -> i64;      // Avogadro, 1/mol
extern fn nuc_const_R() -> i64;       // gas constant, J/(mol·K)
extern fn nuc_const_eps0() -> i64;    // vacuum permittivity, F/m
extern fn nuc_const_mu0() -> i64;     // vacuum permeability, N/A²
extern fn nuc_const_sigma() -> i64;   // Stefan-Boltzmann, W/(m²·K⁴)
extern fn nuc_const_alpha() -> i64;   // fine-structure (dimensionless)
extern fn nuc_const_a0() -> i64;      // Bohr radius, m
extern fn nuc_const_Rinf() -> i64;    // Rydberg, 1/m
extern fn nuc_const_eV() -> i64;      // electron-volt, J
extern fn nuc_const_u() -> i64;       // atomic mass unit, kg

// --- Math constants ---
extern fn nuc_const_pi() -> i64;      // π
extern fn nuc_const_euler() -> i64;   // e

// --- Convenience scientific constants ---
extern fn nuc_const_vsound() -> i64;  // speed of sound in air at 20°C, m/s

// Friendly Nucleor-side accessors (use the same name as the C symbol minus prefix).
fn const_c()      -> i64 { return nuc_const_c(); }
fn const_h()      -> i64 { return nuc_const_h(); }
fn const_hbar()   -> i64 { return nuc_const_hbar(); }
fn const_kb()     -> i64 { return nuc_const_kb(); }
fn const_e()      -> i64 { return nuc_const_e(); }
fn const_me()     -> i64 { return nuc_const_me(); }
fn const_mp()     -> i64 { return nuc_const_mp(); }
fn const_mn()     -> i64 { return nuc_const_mn(); }
fn const_G()      -> i64 { return nuc_const_G(); }
fn const_Na()     -> i64 { return nuc_const_Na(); }
fn const_R()      -> i64 { return nuc_const_R(); }
fn const_eps0()   -> i64 { return nuc_const_eps0(); }
fn const_mu0()    -> i64 { return nuc_const_mu0(); }
fn const_sigma()  -> i64 { return nuc_const_sigma(); }
fn const_alpha()  -> i64 { return nuc_const_alpha(); }
fn const_a0()     -> i64 { return nuc_const_a0(); }
fn const_Rinf()   -> i64 { return nuc_const_Rinf(); }
fn const_eV()     -> i64 { return nuc_const_eV(); }
fn const_u()      -> i64 { return nuc_const_u(); }
fn const_pi()     -> i64 { return nuc_const_pi(); }
fn const_euler()  -> i64 { return nuc_const_euler(); }
fn const_vsound() -> i64 { return nuc_const_vsound(); }
