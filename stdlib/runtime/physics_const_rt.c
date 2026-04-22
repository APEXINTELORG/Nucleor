// physics_const_rt.c — Physical Constants (CODATA 2018) for Nucleor
// All values returned as f64 (bitcast to i64).
//
// Compile: clang -c stdlib/runtime/physics_const_rt.c -o target/physics_const_rt.obj -O2

#include <string.h>

static long long _pc_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// Speed of light in vacuum (m/s)
long long nuc_const_c(void) { return _pc_f2i(299792458.0); }

// Planck constant (J·s)
long long nuc_const_h(void) { return _pc_f2i(6.62607015e-34); }

// Reduced Planck constant (J·s)
long long nuc_const_hbar(void) { return _pc_f2i(1.054571817e-34); }

// Boltzmann constant (J/K)
long long nuc_const_kb(void) { return _pc_f2i(1.380649e-23); }

// Elementary charge (C)
long long nuc_const_e(void) { return _pc_f2i(1.602176634e-19); }

// Electron mass (kg)
long long nuc_const_me(void) { return _pc_f2i(9.1093837015e-31); }

// Proton mass (kg)
long long nuc_const_mp(void) { return _pc_f2i(1.67262192369e-27); }

// Neutron mass (kg)
long long nuc_const_mn(void) { return _pc_f2i(1.67492749804e-27); }

// Gravitational constant (m^3/(kg·s^2))
long long nuc_const_G(void) { return _pc_f2i(6.67430e-11); }

// Avogadro number (1/mol)
long long nuc_const_Na(void) { return _pc_f2i(6.02214076e23); }

// Gas constant (J/(mol·K))
long long nuc_const_R(void) { return _pc_f2i(8.314462618); }

// Vacuum permittivity (F/m)
long long nuc_const_eps0(void) { return _pc_f2i(8.8541878128e-12); }

// Vacuum permeability (H/m)
long long nuc_const_mu0(void) { return _pc_f2i(1.25663706212e-6); }

// Stefan-Boltzmann constant (W/(m^2·K^4))
long long nuc_const_sigma(void) { return _pc_f2i(5.670374419e-8); }

// Fine-structure constant (dimensionless)
long long nuc_const_alpha(void) { return _pc_f2i(7.2973525693e-3); }

// Bohr radius (m)
long long nuc_const_a0(void) { return _pc_f2i(5.29177210903e-11); }

// Rydberg constant (1/m)
long long nuc_const_Rinf(void) { return _pc_f2i(10973731.568160); }

// Electron volt (J)
long long nuc_const_eV(void) { return _pc_f2i(1.602176634e-19); }

// Atomic mass unit (kg)
long long nuc_const_u(void) { return _pc_f2i(1.66053906660e-27); }

// Pi
long long nuc_const_pi(void) { return _pc_f2i(3.14159265358979323846); }

// Euler's number
long long nuc_const_euler(void) { return _pc_f2i(2.71828182845904523536); }

// Speed of sound in air at 20°C (m/s)
long long nuc_const_vsound(void) { return _pc_f2i(343.0); }
