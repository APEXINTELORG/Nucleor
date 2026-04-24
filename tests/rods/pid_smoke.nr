// rods/pid — verify rod wrapper compiles + links (v0.2.257 ship).
// Build-only smoke; correctness coverage in the direct C unit
// test (P-only step, PI integrator, anti-windup, full PID
// closed-loop on a 1st-order plant).
import "stdlib/rods/pid.nr"

fn main() -> i64 {
    print("OK pid_smoke");
    return 0;
}
