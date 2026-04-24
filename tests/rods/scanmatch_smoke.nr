// rods/scanmatch — verify rod wrapper compiles + links (v0.2.293 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (synthetic 2D scan transformed by known (dx, dy, dt); ICP
// recovers the transform from a zero initial guess).
import "stdlib/rods/scanmatch.nr"

fn main() -> i64 {
    print("OK scanmatch_smoke");
    return 0;
}
