// rods/dubins — verify rod wrapper compiles + links (v0.2.295 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (colinear same-heading → Euclidean = straight length; reverse
// heading → non-trivial Dubins path > Euclidean).
import "stdlib/rods/dubins.nr"

fn main() -> i64 {
    print("OK dubins_smoke");
    return 0;
}
