// rods/handeye — verify rod wrapper compiles + links (v0.2.232 ship).
// Build-only smoke; functional calibration needs allocated motion-
// pair arrays, non-trivial in a single test file. Correctness
// coverage in the direct C unit test (synthetic AX=XB sequence
// recovers the planted X transform).
import "stdlib/rods/handeye.nr"

fn main() -> i64 {
    print("OK handeye_smoke");
    return 0;
}
