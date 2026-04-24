// rods/admit — verify rod wrapper compiles + links (v0.2.270 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (constant force → steady state x = F/K; step force → damped
// oscillation toward steady state).
import "stdlib/rods/admit.nr"

fn main() -> i64 {
    print("OK admit_smoke");
    return 0;
}
