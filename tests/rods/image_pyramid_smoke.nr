// rods/image_pyramid — verify rod wrapper compiles + links (v0.2.303 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (constant image → reduce/expand preserves value; impulse →
// kernel; reduce halves dims; expand restores dims).
import "stdlib/rods/image_pyramid.nr"

fn main() -> i64 {
    print("OK image_pyramid_smoke");
    return 0;
}
