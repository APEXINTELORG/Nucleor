// rods/vision — verify rod wrapper compiles + links (v0.2.224 ship).
// Build-only smoke; functional projection requires K, R, t, and
// point buffers, non-trivial in a single test file. Correctness
// coverage in the direct C test (project a point at (0,0,1) →
// principal point regardless of fx/fy).
import "stdlib/rods/vision.nr"

fn main() -> i64 {
    print("OK vision_smoke");
    return 0;
}
