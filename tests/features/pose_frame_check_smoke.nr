// v0.8.267 R07-D1 Phase 1 — frame-check helpers positive coverage.
//
// Per audit `BUILD_PLAN_R07_robotics_control.md` §1 R07-D1
// (CRITICAL): adopter pattern for frame-tagged poses, runtime check
// layer (Phase 1 ship). Phase 2 wires compile-time TYP-008 typed
// rejection per RFC-0046 Phase B (~200 LOC compiler edit).
//
// Locks 6 invariants on the runtime-check helpers:
//   1. Strict-compat self-match — `compatible_strict(2, 2) == 1`
//      for camera-camera.
//   2. Strict-compat distinct rejects — `compatible_strict(2, 1) == 0`
//      for camera-base (the Mars Climate Orbiter scenario).
//   3. Strict-compat unknown does NOT pass — unlike the lenient
//      `kinematics_frame_compatible`, strict mode rejects unknown
//      against anything except itself.
//   4. frame_assert match — returns 1 for self-match, 0 for
//      mismatch (gates the production check path).
//   5. frame_require match returns expected — returns the
//      expected_id on match, -1 on mismatch (chainable check).
//   6. frame_check_pair — both legs match → 1; either mismatch → 0.
//
// Expected: rc=0.

import "stdlib/rods/kinematics_frame.nr"

fn check_strict_self_match() -> i64 {
    let cam: i64 = kinematics_frame_id_camera();
    if kinematics_frame_compatible_strict(cam, cam) != 1 { return 1; };
    return 0;
}

fn check_strict_distinct_rejects() -> i64 {
    let cam: i64 = kinematics_frame_id_camera();
    let base: i64 = kinematics_frame_id_base();
    if kinematics_frame_compatible_strict(cam, base) != 0 { return 2; };
    if kinematics_frame_compatible_strict(base, cam) != 0 { return 4; };
    return 0;
}

fn check_strict_unknown_rejects() -> i64 {
    // Lenient compat: -1 against anything → 1 (matches).
    // Strict compat: only -1 == -1 passes; -1 vs camera fails.
    let unknown: i64 = kinematics_frame_id_unknown();
    let cam: i64 = kinematics_frame_id_camera();
    if kinematics_frame_compatible_strict(unknown, cam) != 0 { return 8; };
    if kinematics_frame_compatible_strict(cam, unknown) != 0 { return 16; };
    if kinematics_frame_compatible_strict(unknown, unknown) != 1 { return 32; };
    return 0;
}

fn check_frame_assert() -> i64 {
    let cam: i64 = kinematics_frame_id_camera();
    let base: i64 = kinematics_frame_id_base();
    if kinematics_frame_assert(cam, cam) != 1 { return 64; };
    if kinematics_frame_assert(cam, base) != 0 { return 128; };
    return 0;
}

fn check_frame_require() -> i64 {
    let lidar: i64 = kinematics_frame_id_lidar();
    let r1: i64 = kinematics_frame_require(lidar, lidar);
    if r1 != lidar { return 256; };
    let cam: i64 = kinematics_frame_id_camera();
    let r2: i64 = kinematics_frame_require(lidar, cam);
    if r2 != 0 - 1 { return 512; };
    return 0;
}

fn check_frame_check_pair() -> i64 {
    let world: i64 = kinematics_frame_id_world();
    let map: i64 = kinematics_frame_id_map();
    if kinematics_frame_check_pair(world, world) != 1 { return 1024; };
    if kinematics_frame_check_pair(world, map) != 0 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_strict_self_match();
    fails = fails + check_strict_distinct_rejects();
    fails = fails + check_strict_unknown_rejects();
    fails = fails + check_frame_assert();
    fails = fails + check_frame_require();
    fails = fails + check_frame_check_pair();
    return fails;
}
