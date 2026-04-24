// rods/vgraph — verify rod wrapper compiles + links (v0.2.275 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (single square obstacle in middle: shortest path goes around a
// corner, not through; cost ≈ Euclidean detour).
import "stdlib/rods/vgraph.nr"

fn main() -> i64 {
    print("OK vgraph_smoke");
    return 0;
}
