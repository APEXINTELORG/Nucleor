// rods/klt — verify rod wrapper compiles + links (v0.2.282 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (synthetic textured image translated by known (dx, dy); KLT
// recovers the displacement to within sub-pixel accuracy).
import "stdlib/rods/klt.nr"

fn main() -> i64 {
    print("OK klt_smoke");
    return 0;
}
