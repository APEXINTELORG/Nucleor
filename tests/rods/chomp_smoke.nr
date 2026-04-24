// rods/chomp — verify rod wrapper compiles + links (v0.2.217 ship).
// Build-only smoke; functional optimization needs an obstacle-cost
// callback + a path buffer, both non-trivial in a single test file.
// Correctness coverage in the direct C unit test.
import "stdlib/rods/chomp.nr"

fn main() -> i64 {
    print("OK chomp_smoke");
    return 0;
}
