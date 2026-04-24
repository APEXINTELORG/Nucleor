// rods/bezier — verify rod wrapper compiles + links (v0.2.325 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (cubic Bezier endpoints; t=0.5 midpoint of symmetric quadratic;
// 3-D Bezier degree-2 hits midpoint).
import "stdlib/rods/bezier.nr"

fn main() -> i64 {
    print("OK bezier_smoke");
    return 0;
}
