// rods/tf — verify rod wrapper compiles + links (v0.2.286 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (4-frame chain: world → base → arm → gripper; verify lookup
// composes the chain).
import "stdlib/rods/tf.nr"

fn main() -> i64 {
    print("OK tf_smoke");
    return 0;
}
