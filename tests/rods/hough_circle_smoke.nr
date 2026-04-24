// rods/hough_circle — verify rod wrapper compiles + links (v0.2.304 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (synthetic circle of radius R centered at (cx, cy) → Hough recovers
// (cx, cy, R) within one bin).
import "stdlib/rods/hough_circle.nr"

fn main() -> i64 {
    print("OK hough_circle_smoke");
    return 0;
}
