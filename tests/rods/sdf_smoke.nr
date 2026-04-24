// rods/sdf — verify rod wrapper compiles + links (v0.2.268 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (single-circle SDF: query at obstacle center returns -radius;
// at distance d from center returns d - radius; gradient points
// radially outward).
import "stdlib/rods/sdf.nr"

fn main() -> i64 {
    print("OK sdf_smoke");
    return 0;
}
