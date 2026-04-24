// rods/harris — verify rod wrapper compiles + links (v0.2.328 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (synthetic L-corner produces a detected corner at the elbow;
// flat image has no corners; small image with no corners returns 0).
import "stdlib/rods/harris.nr"

fn main() -> i64 {
    print("OK harris_smoke");
    return 0;
}
