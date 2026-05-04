// rods/kinematics_frame — RFC-0046 Phase A: coordinate-frame
// marker types.
//
// The RFC-0046 thesis is that mixing coordinate frames at runtime
// (camera vs. base vs. world vs. lidar vs. gripper) without
// compile-time enforcement is the Mars-Climate-Orbiter class of
// silent miscompute. The full ship needs phantom-typed `Pose<F>`
// + type-checker enforcement of frame matching across `transform`
// boundaries (Phase B, ~200 LOC compiler-side).
//
// Phase A (this rod): canonical zero-size marker structs that
// adopters can use as Frame tags in their own code today. The
// markers are zero-cost — `Frame_Camera`-tagged data has the
// same memory layout as untagged data, but adopters get an
// audit trail in the source ("this Pose is in the camera frame")
// that survives code review.
//
// Phase B (next ship) wires the compiler-side TYP-008
// frame-mismatch check at `transform(p, tf)` call sites.
//
// Workflow today:
//
//   import "stdlib/rods/kinematics_frame.nr"
//
//   // Tag values in your own struct definitions:
//   struct CamPose { translation: Vec3, rotation: Quat, frame: Frame_Camera }
//   struct BasePose { translation: Vec3, rotation: Quat, frame: Frame_Base }
//
//   // Or as runtime metadata via the kinematics_frame_id helper:
//   let f: i64 = kinematics_frame_id_camera();  // returns 1
//   let f2: i64 = kinematics_frame_id_base();   // returns 2

struct Frame_World {}
struct Frame_Base {}
struct Frame_Camera {}
struct Frame_Lidar {}
struct Frame_IMU {}
struct Frame_Gripper {}
struct Frame_Map {}
struct Frame_Odom {}
struct Frame_Unknown {}

// Numeric ID surface for adopters who want a runtime tag instead
// of (or alongside) a phantom-type marker. The IDs are stable
// across rod versions; -1 is reserved for "unknown / not yet set".
fn kinematics_frame_id_world()    -> i64 { return 0; }
fn kinematics_frame_id_base()     -> i64 { return 1; }
fn kinematics_frame_id_camera()   -> i64 { return 2; }
fn kinematics_frame_id_lidar()    -> i64 { return 3; }
fn kinematics_frame_id_imu()      -> i64 { return 4; }
fn kinematics_frame_id_gripper()  -> i64 { return 5; }
fn kinematics_frame_id_map()      -> i64 { return 6; }
fn kinematics_frame_id_odom()     -> i64 { return 7; }
fn kinematics_frame_id_unknown()  -> i64 { return 0 - 1; }

fn kinematics_frame_name(id: i64) -> str {
    if id == 0 { return "world"; };
    if id == 1 { return "base"; };
    if id == 2 { return "camera"; };
    if id == 3 { return "lidar"; };
    if id == 4 { return "imu"; };
    if id == 5 { return "gripper"; };
    if id == 6 { return "map"; };
    if id == 7 { return "odom"; };
    return "unknown";
}

fn kinematics_frame_compatible(a: i64, b: i64) -> i64 {
    if a == b { return 1; };
    if a == 0 - 1 { return 1; };
    if b == 0 - 1 { return 1; };
    return 0;
}
