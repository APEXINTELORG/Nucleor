// rods/hull — verify rod wrapper compiles + links (v0.2.238 ship).
// Build-only smoke; functional hull computation needs allocated
// point + index buffers, non-trivial in a single test file.
// Correctness coverage in the direct C unit test (square +
// interior point → 4-vertex hull, expected area = 4).
import "stdlib/rods/hull.nr"

fn main() -> i64 {
    print("OK hull_smoke");
    return 0;
}
