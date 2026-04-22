// =====================================================
// rods/orbit — Orbital Mechanics
// =====================================================
// Import: import "stdlib/rods/orbit.nr"
// Provides: Keplerian-element to Cartesian conversion, orbital
//   period, Hohmann transfer Δv, two-body propagation, vis-viva
//   speed, escape velocity.
// =====================================================

#cfile "../runtime/orbit_rt.c"

extern fn nuc_orbit_kepler_to_cart(a: i64, e: i64, inc: i64, omega: i64, Omega: i64, nu: i64, mu: i64) -> i64;
extern fn nuc_orbit_period(a: i64, mu: i64) -> i64;
extern fn nuc_orbit_hohmann(r1: i64, r2: i64, mu: i64) -> i64;
extern fn nuc_orbit_propagate(state: i64, mu: i64, dt: i64) -> i64;
extern fn nuc_orbit_vis_viva(r: i64, a: i64, mu: i64) -> i64;
extern fn nuc_orbit_escape_velocity(r: i64, mu: i64) -> i64;

fn orbit_kepler_to_cart(a: i64, e: i64, inc: i64, omega: i64, Omega: i64, nu: i64, mu: i64) -> i64 {
    return nuc_orbit_kepler_to_cart(a, e, inc, omega, Omega, nu, mu);
}
fn orbit_period(a: i64, mu: i64) -> i64 { return nuc_orbit_period(a, mu); }
fn orbit_hohmann(r1: i64, r2: i64, mu: i64) -> i64 { return nuc_orbit_hohmann(r1, r2, mu); }
fn orbit_propagate(state: i64, mu: i64, dt: i64) -> i64 { return nuc_orbit_propagate(state, mu, dt); }
fn orbit_vis_viva(r: i64, a: i64, mu: i64) -> i64 { return nuc_orbit_vis_viva(r, a, mu); }
fn orbit_escape_velocity(r: i64, mu: i64) -> i64 { return nuc_orbit_escape_velocity(r, mu); }
