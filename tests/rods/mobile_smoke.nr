// rods/mobile — verify rod wrapper compiles + links (v0.2.283 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (diff-drive fwd/inv roundtrip; Ackermann tan-relation; pose
// update for a circle and a straight line).
import "stdlib/rods/mobile.nr"

fn main() -> i64 {
    print("OK mobile_smoke");
    return 0;
}
