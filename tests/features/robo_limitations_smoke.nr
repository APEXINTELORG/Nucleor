// v0.8.270 R07-D4 Phase 1 — limitation diagnostics for control rods.
//
// Per audit `BUILD_PLAN_R07_robotics_control.md` §1 R07-D4 (MEDIUM):
// pre-v0.8.270 TOPP, AHRS, and CHOMP rods had documented
// approximations buried in source comments but no adopter-facing
// query. Phase 1 ships `*_limitations() -> str` helpers that return
// the rod's known constraints so adopter test harnesses can assert
// what they're getting before committing to production.
//
// Phase 1 acceptance (this ship):
//   - limitation fixture reports known constraints deterministically
//     (each helper returns a non-empty string with key terms);
//   - cold compile <= 4s (preserved — rod-only edits).
//
// Phase 2 (per build plan §1 R07-D4): improve algorithms behind the
// same API (e.g. AHRS 9-DOF magnetometer fusion; CHOMP exact-grad
// SDF + Cartesian variant; TOPP-RA convex per-step + dynamics).
//
// Locks 6 invariants — each rod's limitations() helper:
//   1. AHRS limitations non-empty + names key constraint — string
//      contains "Mahony" (the algorithm) and "magnetometer" (the
//      missing-yaw-observability driver).
//   2. CHOMP limitations non-empty + names key constraint —
//      string contains "joint-space" (no Cartesian variant) and
//      "finite differences" (the slow-grad approximation).
//   3. TOPP limitations non-empty + names key constraint —
//      string contains "piecewise-linear" (only allowed input
//      shape) and "kinematic" (no dynamics).
//   4. All three are distinct — adopters can tell them apart.
//
// Expected: rc=0.

import "stdlib/rods/ahrs.nr"
import "stdlib/rods/chomp.nr"
import "stdlib/rods/trajectory.nr"

fn check_ahrs_limitations() -> i64 {
    let s: str = ahrs_limitations();
    if str_len(s) == 0 { return 1; };
    if str_index_of(s, "Mahony") < 0 { return 2; };
    if str_index_of(s, "magnetometer") < 0 { return 4; };
    return 0;
}

fn check_chomp_limitations() -> i64 {
    let s: str = chomp_limitations();
    if str_len(s) == 0 { return 8; };
    if str_index_of(s, "joint-space") < 0 { return 16; };
    if str_index_of(s, "finite differences") < 0 { return 32; };
    return 0;
}

fn check_topp_limitations() -> i64 {
    let s: str = topp_limitations();
    if str_len(s) == 0 { return 64; };
    if str_index_of(s, "piecewise-linear") < 0 { return 128; };
    if str_index_of(s, "kinematic") < 0 { return 256; };
    return 0;
}

fn check_distinct() -> i64 {
    let a: str = ahrs_limitations();
    let c: str = chomp_limitations();
    let t: str = topp_limitations();
    if str_eq(a, c) == 1 { return 512; };
    if str_eq(c, t) == 1 { return 1024; };
    if str_eq(a, t) == 1 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_ahrs_limitations();
    fails = fails + check_chomp_limitations();
    fails = fails + check_topp_limitations();
    fails = fails + check_distinct();
    return fails;
}
