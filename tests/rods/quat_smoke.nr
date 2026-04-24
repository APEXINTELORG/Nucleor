// rods/quat — verify rod wrapper compiles + links (v0.2.327 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (axis-angle round-trip; identity quat rotates any vec to itself;
// 90° about z rotates +x to +y; slerp midpoint of 0° and 180° about
// z is 90° about z; Hamilton product of two 90° rots = 180°).
import "stdlib/rods/quat.nr"

fn main() -> i64 {
    print("OK quat_smoke");
    return 0;
}
