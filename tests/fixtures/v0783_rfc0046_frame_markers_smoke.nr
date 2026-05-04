// v0.7.83 RFC-0046 Phase A smoke fixture — coordinate-frame
// marker types + numeric ID surface. Validates that:
//   - the canonical Frame_* marker structs construct cleanly
//     (zero-size tags adopters can paste into their own structs)
//   - the numeric ID surface returns stable values
//   - kinematics_frame_compatible distinguishes Camera from Base
//     and treats Unknown (-1) as a wildcard
//   - the name lookup returns the expected string
import "stdlib/rods/kinematics_frame.nr"

fn main() -> i64 {
    let m1: Frame_World = Frame_World {};
    let m2: Frame_Camera = Frame_Camera {};
    let m3: Frame_Base = Frame_Base {};
    let m4: Frame_Unknown = Frame_Unknown {};

    if kinematics_frame_id_world() != 0 { return 1; };
    if kinematics_frame_id_base() != 1 { return 2; };
    if kinematics_frame_id_camera() != 2 { return 3; };
    if kinematics_frame_id_unknown() != 0 - 1 { return 4; };

    let cam: i64 = kinematics_frame_id_camera();
    let base: i64 = kinematics_frame_id_base();
    let unk: i64 = kinematics_frame_id_unknown();

    if kinematics_frame_compatible(cam, base) != 0 { return 5; };
    if kinematics_frame_compatible(cam, cam) != 1 { return 6; };
    if kinematics_frame_compatible(cam, unk) != 1 { return 7; };
    if kinematics_frame_compatible(unk, base) != 1 { return 8; };

    let n: str = kinematics_frame_name(2);
    if str_eq(n, "camera") == 0 { return 9; };

    return 0;
}
