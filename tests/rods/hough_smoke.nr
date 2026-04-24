// rods/hough — verify rod wrapper compiles + links (v0.2.296 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (points on known line → Hough recovers (ρ, θ) of that line).
import "stdlib/rods/hough.nr"

fn main() -> i64 {
    print("OK hough_smoke");
    return 0;
}
