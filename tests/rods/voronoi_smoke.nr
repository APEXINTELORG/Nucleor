// rods/voronoi — verify rod wrapper compiles + links (v0.2.306 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (square + center → 4 finite vertices, 4 hull edges going to ∞,
// internal edges between adjacent triangles).
import "stdlib/rods/voronoi.nr"

fn main() -> i64 {
    print("OK voronoi_smoke");
    return 0;
}
