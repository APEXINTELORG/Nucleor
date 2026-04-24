// rods/purepursuit — verify rod wrapper compiles + links (v0.2.297 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (straight-line path with off-axis robot pose → steers toward path).
import "stdlib/rods/purepursuit.nr"

fn main() -> i64 {
    print("OK purepursuit_smoke");
    return 0;
}
