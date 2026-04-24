// rods/canny — verify rod wrapper compiles + links (v0.2.331 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (vertical edge produces edge pixels on the seam; flat image
// produces no edges; hysteresis links a weak edge to a strong one).
import "stdlib/rods/canny.nr"

fn main() -> i64 {
    print("OK canny_smoke");
    return 0;
}
