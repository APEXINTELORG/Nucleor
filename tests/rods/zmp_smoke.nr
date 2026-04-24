// rods/zmp — verify rod wrapper compiles + links (v0.2.269 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (constant-ZMP reference → constant CoM equilibrium; step-change
// ZMP → tracked with bounded error; CoM trajectory smooth).
import "stdlib/rods/zmp.nr"

fn main() -> i64 {
    print("OK zmp_smoke");
    return 0;
}
