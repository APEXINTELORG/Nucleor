// rods/dwa — verify rod wrapper compiles + links (v0.2.240 ship).
// Build-only smoke; functional planning needs an obstacle-distance
// callback, non-trivial in a single test file. Correctness coverage
// in the direct C unit test (single obstacle in front of robot →
// DWA chooses non-zero ω to steer around it).
import "stdlib/rods/dwa.nr"

fn main() -> i64 {
    print("OK dwa_smoke");
    return 0;
}
