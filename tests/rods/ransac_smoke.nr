// rods/ransac — verify rod wrapper compiles + links (v0.2.231 ship).
// Build-only smoke; functional fitting requires a point-cloud
// buffer, non-trivial in a single test file. Correctness coverage
// in the direct C unit test (synthetic z=0 plane with outliers).
import "stdlib/rods/ransac.nr"

fn main() -> i64 {
    print("OK ransac_smoke");
    return 0;
}
