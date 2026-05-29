// v0.8.241 stdlib/rods/pf.nr first test coverage.
//
// Particle filter (sequential Monte Carlo) for nonlinear /
// non-Gaussian state estimation. Pre-v0.8.241: zero coverage on
// the standalone rod. predict / update / init_uniform need
// fn-pointer + raw double[]; deferred to dedicated SLAM ships.
//
// Locks four lifecycle invariants:
//
//   1. pf_new returns valid handle — non-zero.
//   2. particle_count round-trip — n_particles arg is
//      preserved across the constructor.
//   3. Multiple distinct PFs — two constructions return
//      distinct handles (no aliased particle pools).
//   4. pf_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/pf.nr"

fn check_new_valid() -> i64 {
    let h: i64 = pf_new(3, 2, 100, 42);
    if h == 0 { return 1; };
    nuc_pf_free(h);
    return 0;
}

fn check_particle_count_round_trip() -> i64 {
    let h: i64 = pf_new(3, 2, 256, 42);
    if nuc_pf_particle_count(h) != 256 { nuc_pf_free(h); return 2; };
    nuc_pf_free(h);
    return 0;
}

fn check_distinct_handles() -> i64 {
    let a: i64 = pf_new(2, 1, 50, 1);
    let b: i64 = pf_new(2, 1, 50, 2);
    let same: i64 = if a == b { 1 } else { 0 };
    nuc_pf_free(a);
    nuc_pf_free(b);
    if same == 1 { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = pf_new(2, 1, 32, 999);
    nuc_pf_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_particle_count_round_trip();
    fails = fails + check_distinct_handles();
    fails = fails + check_free_non_crashing();
    return fails;
}
