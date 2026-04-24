// rods/se3 — verify rod wrapper compiles + links (v0.2.285 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (compose/inverse roundtrip = identity, apply matches manual
// rotation, log/exp roundtrip).
import "stdlib/rods/se3.nr"

fn main() -> i64 {
    print("OK se3_smoke");
    return 0;
}
