// rods/rdp — verify rod wrapper compiles + links (v0.2.294 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (straight line → only endpoints kept; noisy curve → intermediate
// peaks kept; ε=0 keeps all unique points).
import "stdlib/rods/rdp.nr"

fn main() -> i64 {
    print("OK rdp_smoke");
    return 0;
}
