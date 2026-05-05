// v0.8.206 stdlib/rods/kinematics_frame.nr first test coverage.
//
// RFC-0046 Phase A: coordinate-frame marker types (Frame_World,
// Frame_Base, Frame_Camera, ...). Pre-v0.8.206: audit-pass
// token-presence gate exists (v0.8.181) but no behavioral
// fixture. Mars-Climate-Orbiter-class silent miscompute is the
// motivating risk this rod prevents (Phase B compiler enforcement
// of TYP-008 frame mismatch).
//
// Locks four invariants Phase B compiler enforcement must NOT
// regress:
//
//   1. **Stable IDs** — world=0, base=1, camera=2, lidar=3,
//      imu=4, gripper=5, map=6, odom=7, unknown=-1.
//   2. **Compatibility same** — frame_compatible(camera, camera) = 1.
//   3. **Compatibility unknown** — unknown side is always
//      compatible (both directions).
//   4. **Compatibility cross-frame fails** — camera vs base = 0
//      (the core silent-miscompute guard).
//
// Expected: rc=0.

import "stdlib/rods/kinematics_frame.nr"

fn check_stable_ids() -> i64 {
    if kinematics_frame_id_world() != 0 { return 1; };
    if kinematics_frame_id_base() != 1 { return 2; };
    if kinematics_frame_id_camera() != 2 { return 4; };
    if kinematics_frame_id_lidar() != 3 { return 8; };
    if kinematics_frame_id_imu() != 4 { return 16; };
    if kinematics_frame_id_gripper() != 5 { return 32; };
    if kinematics_frame_id_map() != 6 { return 64; };
    if kinematics_frame_id_odom() != 7 { return 128; };
    if kinematics_frame_id_unknown() != (0 - 1) { return 256; };
    return 0;
}

fn check_compat_same() -> i64 {
    if kinematics_frame_compatible(kinematics_frame_id_camera(), kinematics_frame_id_camera()) != 1 { return 512; };
    return 0;
}

fn check_compat_unknown() -> i64 {
    if kinematics_frame_compatible(kinematics_frame_id_unknown(), kinematics_frame_id_camera()) != 1 { return 1024; };
    if kinematics_frame_compatible(kinematics_frame_id_camera(), kinematics_frame_id_unknown()) != 1 { return 2048; };
    return 0;
}

fn check_compat_cross_frame_fails() -> i64 {
    if kinematics_frame_compatible(kinematics_frame_id_camera(), kinematics_frame_id_base()) != 0 { return 4096; };
    if kinematics_frame_compatible(kinematics_frame_id_lidar(), kinematics_frame_id_imu()) != 0 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_stable_ids();
    fails = fails + check_compat_same();
    fails = fails + check_compat_unknown();
    fails = fails + check_compat_cross_frame_fails();
    return fails;
}
