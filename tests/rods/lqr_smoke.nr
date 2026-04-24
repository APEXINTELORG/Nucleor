// rods/lqr — verify rod wrapper compiles + links (v0.2.258 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (1-DOF integrator, 2-DOF double integrator, closed-loop sim
// driving state to origin from a non-zero initial condition).
import "stdlib/rods/lqr.nr"

fn main() -> i64 {
    print("OK lqr_smoke");
    return 0;
}
