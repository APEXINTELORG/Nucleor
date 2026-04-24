// rods/cilqr — verify rod wrapper compiles + links (v0.2.267 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (1-D double integrator with tight u-bounds — verify u stays in
// box and cost still decreases).
import "stdlib/rods/cilqr.nr"

fn main() -> i64 {
    print("OK cilqr_smoke");
    return 0;
}
