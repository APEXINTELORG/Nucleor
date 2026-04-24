// rods/cubicspline — verify rod wrapper compiles + links (v0.2.324 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (sample at a knot returns the knot's y; sample on a linear data
// set returns near-linear interpolation; non-monotonic xs returns 0).
import "stdlib/rods/cubicspline.nr"

fn main() -> i64 {
    print("OK cubicspline_smoke");
    return 0;
}
