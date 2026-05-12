// v0.8.145 RFC-0046 Phase B step-1 — Pose<F> + Frame_* marker
// audit (V2.1 frontier easy-win).
//
// `kinematics_frame` rod already ships zero-cost frame marker
// structs (Frame_World / Frame_Base / Frame_Camera / Frame_Lidar
// / Frame_IMU). Phase B step-1 surfaces adopter usage of these
// markers and `Pose<F>` phantom-frame type-position annotations
// at build time, matching the RFC-0043 fixed<I,F> audit pattern.
//
// Phase B step-2 (true `types_compatible(Pose<Camera>,
// Pose<Base>) == 0` phantom-type checking) is the ~200 LOC
// compiler ship.
//
// This fixture exercises Frame_* marker types in let-position
// only (the `Pose<F>` parametric form would require the full
// generic infra, deferred). Locks that the regression gate counts
// markers and that the program compiles + runs cleanly with
// rc=0.
//
// Expected: rc=0; build emits "audit: Frame_* marker uses
// (let/arg position): 5".

import "stdlib/rods/kinematics_frame.nr"

fn main() -> i64 {
    let world: Frame_World = Frame_World {};
    let base: Frame_Base = Frame_Base {};
    let cam: Frame_Camera = Frame_Camera {};
    let lid: Frame_Lidar = Frame_Lidar {};
    let imu: Frame_IMU = Frame_IMU {};
    let _ = world;
    let _ = base;
    let _ = cam;
    let _ = lid;
    let _ = imu;
    return 0;
}
