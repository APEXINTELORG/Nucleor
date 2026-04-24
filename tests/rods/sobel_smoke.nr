// rods/sobel — verify rod wrapper compiles + links (v0.2.330 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (vertical step edge → strong Gx; horizontal step edge → strong
// Gy; flat image → all zero gradient).
import "stdlib/rods/sobel.nr"

fn main() -> i64 {
    print("OK sobel_smoke");
    return 0;
}
