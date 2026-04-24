// rods/qutil — verify rod wrapper compiles + links (v0.2.265 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (slerp endpoints + midpoint, log/exp roundtrip, axis-angle and
// Euler conversions, relative-rotation identity).
import "stdlib/rods/qutil.nr"

fn main() -> i64 {
    print("OK qutil_smoke");
    return 0;
}
