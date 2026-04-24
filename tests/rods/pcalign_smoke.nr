// rods/pcalign — verify rod wrapper compiles + links (v0.2.288 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (synthetic point cloud transformed by known (R, t); pcalign
// recovers it exactly).
import "stdlib/rods/pcalign.nr"

fn main() -> i64 {
    print("OK pcalign_smoke");
    return 0;
}
