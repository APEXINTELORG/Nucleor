// rods/skid_steer — verify rod wrapper compiles + links (v0.2.334 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (all-equal wheels → straight; per-side asymmetry → spin; round-trip
// fwd-then-inv-kin recovers original commands).
import "stdlib/rods/skid_steer.nr"

fn main() -> i64 {
    print("OK skid_steer_smoke");
    return 0;
}
