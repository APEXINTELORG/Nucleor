// rods/dstar — verify rod wrapper compiles + links (v0.2.262 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (open grid plan, obstacle insertion forces replan around it,
// removal restores the shorter path).
import "stdlib/rods/dstar.nr"

fn main() -> i64 {
    print("OK dstar_smoke");
    return 0;
}
