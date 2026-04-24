// rods/imgproc — verify rod wrapper compiles + links (v0.2.280 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (Sobel on a vertical edge → strong horizontal gradient; Gaussian
// blur preserves total mass; resize roundtrip).
import "stdlib/rods/imgproc.nr"

fn main() -> i64 {
    print("OK imgproc_smoke");
    return 0;
}
