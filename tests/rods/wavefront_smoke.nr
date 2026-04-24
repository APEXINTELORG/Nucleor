// rods/wavefront — verify rod wrapper compiles + links (v0.2.291 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (open grid → Chebyshev-like distance; obstacles block propagation;
// multi-start returns minimum-over-starts field).
import "stdlib/rods/wavefront.nr"

fn main() -> i64 {
    print("OK wavefront_smoke");
    return 0;
}
