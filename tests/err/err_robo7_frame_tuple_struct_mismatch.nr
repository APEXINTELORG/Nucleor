// EXPECT: error[FRAME-001] cannot initialize tuple-struct 'PoseSlot' field '__0': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B step 3: tuple-struct construction
// should surface FRAME-001 for positional frame mismatches.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }
struct PoseSlot(Pose<Frame_Camera>);

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn main() -> i64 {
    let p_base: Pose<Frame_Base> = make_pose();
    let slot: PoseSlot = PoseSlot(p_base);
    return slot.0.translation;
}
