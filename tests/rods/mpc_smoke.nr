// rods/mpc — verify rod wrapper compiles + links (v0.2.260 ship).
// Build-only smoke; correctness coverage in the direct C unit
// test (closed-loop MPC on 1-D double-integrator goal-reaching).
import "stdlib/rods/mpc.nr"

fn main() -> i64 {
    print("OK mpc_smoke");
    return 0;
}
