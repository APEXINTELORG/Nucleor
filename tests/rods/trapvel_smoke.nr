// rods/trapvel — verify rod wrapper compiles + links (v0.2.323 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (long move = trapezoidal w/ cruise; short move = triangular;
// total time matches analytical formula; sample at t=0 returns
// start; sample at t=total returns goal).
import "stdlib/rods/trapvel.nr"

fn main() -> i64 {
    print("OK trapvel_smoke");
    return 0;
}
