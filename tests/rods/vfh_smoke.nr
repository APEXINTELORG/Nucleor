// rods/vfh — verify rod wrapper compiles + links (v0.2.300 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (empty grid → goal bearing returned; obstacle dead-ahead pushes
// steer to one side; full ring of obstacles → fails).
import "stdlib/rods/vfh.nr"

fn main() -> i64 {
    print("OK vfh_smoke");
    return 0;
}
