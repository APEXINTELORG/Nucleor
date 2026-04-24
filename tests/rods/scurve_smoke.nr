// rods/scurve — verify rod wrapper compiles + links (v0.2.266 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (boundary conditions, peak velocity = v_max, peak accel = a_max,
// peak jerk = j_max, total time matches analytical formula).
import "stdlib/rods/scurve.nr"

fn main() -> i64 {
    print("OK scurve_smoke");
    return 0;
}
