// rods/ilqr — verify rod wrapper compiles + links (v0.2.222 ship).
// Build-only smoke; functional optimization needs dynamics + cost
// callbacks, both non-trivial in a single test file. Correctness
// coverage in the direct C unit test (1D double-integrator
// regulator).
import "stdlib/rods/ilqr.nr"

fn main() -> i64 {
    print("OK ilqr_smoke");
    return 0;
}
