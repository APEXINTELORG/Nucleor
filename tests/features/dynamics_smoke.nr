// v0.8.241 stdlib/rods/dynamics.nr first test coverage.
//
// Robot inverse dynamics via Recursive Newton-Euler (RNEA).
// Pre-v0.8.241: zero coverage on the standalone rod. inverse /
// forward / mass_matrix / cartesian_impedance all use raw
// double[] pointers; deferred to dedicated robot-control ships.
//
// Locks four lifecycle invariants on the scalar-only setter
// surface (link mass, link CoM, link inertia tensor, joint
// friction, motor inertia, gravity). dyn_new requires the
// FK chain to have at least one joint registered (n_links > 0).
//
//   1. dyn_new returns valid handle — wraps a fresh
//      fk_chain that has joints.
//   2. set_link_mass + set_link_com per index — exercises
//      the scalar per-link setters.
//   3. set_link_inertia per index — exercises 6-arg
//      symmetric inertia tensor setter.
//   4. set_gravity does not crash — typical Earth gravity
//      (0, 0, -9.81).
//
// Expected: rc=0.

import "stdlib/rods/dynamics.nr"

fn make_fk_with_joints(n: i64) -> i64 {
    let ch: i64 = fk_chain_new();
    let mut i: i64 = 0;
    while i < n {
        nuc_fk_chain_add_joint(ch, fk_revolute(),
            f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
            f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
            f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0)
        );
        i = i + 1;
    };
    return ch;
}

fn check_dyn_new_valid() -> i64 {
    let fk: i64 = make_fk_with_joints(2);
    let h: i64 = nuc_dyn_new(fk);
    if h == 0 { return 1; };
    return 0;
}

fn check_set_mass_com_per_index() -> i64 {
    let fk: i64 = make_fk_with_joints(2);
    let h: i64 = nuc_dyn_new(fk);
    nuc_dyn_set_link_mass(h, 0, f64_to_bits(1.0));
    nuc_dyn_set_link_mass(h, 1, f64_to_bits(2.0));
    nuc_dyn_set_link_com(h, 0,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.5));
    nuc_dyn_set_link_com(h, 1,
        f64_to_bits(0.1), f64_to_bits(0.0), f64_to_bits(0.0));
    return 0;
}

fn check_set_inertia_per_index() -> i64 {
    let fk: i64 = make_fk_with_joints(2);
    let h: i64 = nuc_dyn_new(fk);
    nuc_dyn_set_link_inertia(h, 0,
        f64_to_bits(0.1), f64_to_bits(0.1), f64_to_bits(0.1),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0)
    );
    return 0;
}

fn check_set_gravity() -> i64 {
    let fk: i64 = make_fk_with_joints(2);
    let h: i64 = nuc_dyn_new(fk);
    nuc_dyn_set_gravity(h,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0 - 9.81));
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_dyn_new_valid();
    fails = fails + check_set_mass_com_per_index();
    fails = fails + check_set_inertia_per_index();
    fails = fails + check_set_gravity();
    return fails;
}
