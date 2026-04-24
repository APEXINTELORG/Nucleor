// rods/mppi — verify rod wrapper compiles + links (v0.2.273 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (closed-loop MPPI on 1-D double-integrator goal-reach — verify
// state converges to goal under the sample-based controller).
import "stdlib/rods/mppi.nr"

fn main() -> i64 {
    print("OK mppi_smoke");
    return 0;
}
