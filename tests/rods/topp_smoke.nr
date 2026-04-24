// rods/topp — verify rod wrapper compiles + links (v0.2.263 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (trapezoidal vs triangular profile selection, boundary conditions
// at start/end, total time matches analytical formula).
import "stdlib/rods/topp.nr"

fn main() -> i64 {
    print("OK topp_smoke");
    return 0;
}
