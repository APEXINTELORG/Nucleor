// rods/catmullrom — verify rod wrapper compiles + links (v0.2.326 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (sample at integer t hits the corresponding control point;
// 4 colinear points → spline stays on the line; 3-D interpolation
// matches expected midpoint).
import "stdlib/rods/catmullrom.nr"

fn main() -> i64 {
    print("OK catmullrom_smoke");
    return 0;
}
