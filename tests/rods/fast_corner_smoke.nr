// rods/fast_corner — verify rod wrapper compiles + links (v0.2.329 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (synthetic L-corner finds the elbow; flat image has no corners).
import "stdlib/rods/fast_corner.nr"

fn main() -> i64 {
    print("OK fast_corner_smoke");
    return 0;
}
