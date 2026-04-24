// rods/hwbc — verify rod wrapper compiles + links (v0.2.264 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (single full-rank task; conflicting tasks where strict priority
// must hold; redundant arm with primary task + secondary posture).
import "stdlib/rods/hwbc.nr"

fn main() -> i64 {
    print("OK hwbc_smoke");
    return 0;
}
