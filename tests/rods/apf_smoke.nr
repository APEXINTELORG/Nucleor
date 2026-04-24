// rods/apf — verify rod wrapper compiles + links (v0.2.241 ship).
// Build-only smoke; functional force computation needs allocated
// obstacle + output buffers, non-trivial in a single test file.
// Correctness coverage in the direct C unit test (single obstacle
// → robot drives around it toward goal).
import "stdlib/rods/apf.nr"

fn main() -> i64 {
    print("OK apf_smoke");
    return 0;
}
