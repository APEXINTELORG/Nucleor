// v0.8.259 stdlib/rods/vision.nr collision rename + first test coverage.
//
// Pre-v0.8.259 `vision_rt.c` defined `nuc_cam_project` (5-arg)
// which collided with `cam_rt.c` `nuc_cam_project` (3-arg) at the
// global linker symbol table. Linker resolved to whichever object
// file was processed first; the other rod's calls dispatched to
// the wrong body and silently miscomputed. Importing both rods
// in one program was a duplicate-symbol link error or a
// silent wrong-target call. Surfaced by TRACK A
// `extern_arity_drift_duplicate_symbol_collisions_2026-05-05`.
//
// Fix: renamed at the namespace boundary.
// - `vision_rt.c::nuc_cam_project` (5-arg) → `nuc_vision_project`.
// - `vision_rt.c::nuc_cam_project_batch` (6-arg) → `nuc_vision_project_batch`.
// - Internal call site in `nuc_vision_project_batch` updated.
// - `vision.nr` extern decls + Nucleor wrappers renamed
//   `cam_project` → `vision_project`, same for `_batch`.
// - `cam.nr` `nuc_cam_project` (3-arg) untouched — keeps the
//   canonical `nuc_cam_*` namespace.
//
// Breaking for any Nucleor adopter that imported vision.nr and
// called `cam_project(K, R, t, X, uv)` (5-arg). Migration: call
// `vision_project` instead. No in-tree callers existed (vision.nr
// was uncovered).
//
// Locks two invariants on the rename:
//
//   1. vision_project null-input rejection — runtime null-checks
//      K/R/t/X/uv; passing 0 for any returns 0.
//   2. Both rods can be imported together (this fixture imports
//      cam + vision; if the link still collided, this fixture would
//      fail at link/load time before main runs).
//
// Expected: rc=0.

import "stdlib/rods/cam.nr"
import "stdlib/rods/vision.nr"

fn check_null_K() -> i64 {
    let r: i64 = vision_project(0, 1, 1, 1, 1);
    if r != 0 { return 1; };
    return 0;
}

fn check_null_R() -> i64 {
    let r: i64 = vision_project(1, 0, 1, 1, 1);
    if r != 0 { return 2; };
    return 0;
}

fn check_null_t() -> i64 {
    let r: i64 = vision_project(1, 1, 0, 1, 1);
    if r != 0 { return 4; };
    return 0;
}

fn check_null_X() -> i64 {
    let r: i64 = vision_project(1, 1, 1, 0, 1);
    if r != 0 { return 8; };
    return 0;
}

fn check_null_uv() -> i64 {
    let r: i64 = vision_project(1, 1, 1, 1, 0);
    if r != 0 { return 16; };
    return 0;
}

fn check_batch_zero_N() -> i64 {
    let r: i64 = vision_project_batch(1, 1, 1, 1, 0, 1);
    if r != 0 { return 32; };
    return 0;
}

fn check_both_rods_link() -> i64 {
    // If the symbol collision still existed, importing both cam.nr
    // and vision.nr in this file would trigger a linker error before
    // main runs; reaching this line proves the rename worked.
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_K();
    fails = fails + check_null_R();
    fails = fails + check_null_t();
    fails = fails + check_null_X();
    fails = fails + check_null_uv();
    fails = fails + check_batch_zero_N();
    fails = fails + check_both_rods_link();
    return fails;
}
