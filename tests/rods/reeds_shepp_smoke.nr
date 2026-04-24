// rods/reeds_shepp — verify rod wrapper compiles + links (v0.2.302 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (forward-only Dubins-equivalent case → matches Dubins length;
// reverse-heading goal → Reeds-Shepp shorter than Dubins;
// colinear same-heading → Euclidean length).
import "stdlib/rods/reeds_shepp.nr"

fn main() -> i64 {
    print("OK reeds_shepp_smoke");
    return 0;
}
