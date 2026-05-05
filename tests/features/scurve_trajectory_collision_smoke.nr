// v0.8.261 stdlib/rods/scurve.nr <-> stdlib/rods/trajectory.nr collision rename.
//
// Pre-v0.8.261 BOTH rods exported `nuc_scurve_new` and `nuc_scurve_free`
// from their respective C runtime files with incompatible signatures
// AND incompatible struct layouts:
//
//   scurve_rt.c    ::nuc_scurve_new   4-arg `(L, v_max, a_max, j_max)`
//   trajectory_rt.c::nuc_scurve_new   5-arg `(q0, qT, v_max, a_max, j_max)`
//   scurve_rt.c    ::nuc_scurve_free  1-arg, frees scurve_rt.c's struct
//   trajectory_rt.c::nuc_scurve_free  1-arg, frees trajectory_rt.c's struct
//
// Plus `nuc_scurve_duration` / `_peak_v` / `_peak_a` / `_pos_at` were
// trajectory-only but reused the `nuc_scurve_*` namespace, leaving
// scurve.nr's similar-looking `_total_time` / `_position` / etc. as
// future collision risks. Importing both rods was a duplicate-symbol
// link error or a silent wrong-target call.
//
// Surfaced by parallel-agent TRACK A
// `extern_arity_drift_duplicate_symbol_collisions_2026-05-05`.
// LAST item of TRACK A — closes the parallel-agent's primary lane.
//
// Fix (trajectory rod renames; scurve rod keeps canonical namespace):
// - trajectory_rt.c: 6 nuc_scurve_* → nuc_traj_scurve_* (new, duration,
//   peak_v, peak_a, pos_at, free).
// - trajectory.nr: extern decls + Nucleor wrappers renamed
//   `scurve_*` → `traj_scurve_*`, including all `_f64` convenience
//   variants.
// - tests/rods/trajectory_smoke.nr + tests/features/trajectory_f64.nr
//   updated to call the new names.
// - scurve.nr untouched — keeps canonical `nuc_scurve_*` namespace.
//
// **Breaking** for any Nucleor adopter that imported trajectory.nr and
// called `scurve_new(q0, qT, vmax, amax, jmax)` 5-arg or related;
// migrate to `traj_scurve_*`. Two in-tree callers updated in this ship.
//
// Locks invariants on the rename:
//   1. **traj_scurve_new + traj_scurve_duration** — q 0→1 with
//      v_max=2, a_max=4, j_max=20 returns a non-zero handle and
//      duration > 0 (proves the renamed runtime is reached and the
//      struct round-trips correctly).
//   2. **traj_scurve_pos_at(0)** — position at t=0 should be q0=0.
//   3. **scurve_new (4-arg) still works in the same file** — calls
//      scurve.nr's distinct API on the same import.
//   4. **Both rods can be imported together** — link-time collision
//      check; reaching `main` proves the rename worked.
//
// Expected: rc=0.

import "stdlib/rods/scurve.nr"
import "stdlib/rods/trajectory.nr"

fn check_traj_scurve_new() -> i64 {
    let sc: i64 = traj_scurve_new(
        f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(2.0), f64_to_bits(4.0), f64_to_bits(20.0)
    );
    if sc == 0 { return 1; };
    let dur: i64 = traj_scurve_duration(sc);
    if dur == 0 { traj_scurve_free(sc); return 2; };
    traj_scurve_free(sc);
    return 0;
}

fn check_traj_scurve_pos_at_zero() -> i64 {
    let sc: i64 = traj_scurve_new(
        f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(2.0), f64_to_bits(4.0), f64_to_bits(20.0)
    );
    if sc == 0 { return 4; };
    let p0_bits: i64 = traj_scurve_pos_at(sc, f64_to_bits(0.0));
    let p0: f64 = f64_from_bits(p0_bits);
    let abs_p0: f64 = if p0 < 0.0 { 0.0 - p0 } else { p0 };
    if abs_p0 > 1e-9 { traj_scurve_free(sc); return 8; };
    traj_scurve_free(sc);
    return 0;
}

fn check_scurve_4arg_still_works() -> i64 {
    // scurve.nr's 4-arg API: (L, v_max, a_max, j_max). Use known-
    // passing values from scurve_smoke.nr (path long enough to
    // reach v_max).
    let h: i64 = scurve_new(
        f64_to_bits(100.0), f64_to_bits(2.0),
        f64_to_bits(1.0),   f64_to_bits(2.0)
    );
    if h == 0 { return 16; };
    let t: i64 = scurve_total_time(h);
    if t == 0 { scurve_free(h); return 32; };
    scurve_free(h);
    return 0;
}

fn check_both_rods_link() -> i64 {
    // If the collision still existed, importing both rods would
    // trigger a linker error before main runs. Reaching this line
    // proves the rename worked.
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_traj_scurve_new();
    fails = fails + check_traj_scurve_pos_at_zero();
    fails = fails + check_scurve_4arg_still_works();
    fails = fails + check_both_rods_link();
    return fails;
}
