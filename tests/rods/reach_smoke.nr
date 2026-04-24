// rods/reach — verify rod wrapper compiles + links (v0.2.276 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (planar 2-link arm: workspace is an annulus; verify density
// inside annulus and bounding-box extent).
import "stdlib/rods/reach.nr"

fn main() -> i64 {
    print("OK reach_smoke");
    return 0;
}
