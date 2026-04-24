// rods/ukf — verify rod wrapper compiles + links (v0.2.234 ship).
// Build-only smoke; functional filtering needs dynamics + measurement
// callbacks, non-trivial in a single test file. Correctness coverage
// in the direct C unit test (1D position+velocity tracker, same
// scenario as the EKF test).
import "stdlib/rods/ukf.nr"

fn main() -> i64 {
    let u: i64 = ukf_new(2, 1, 0);
    if u == 0 { print("FAIL ukf_new"); return 1; };
    ukf_free(u);
    print("OK ukf_smoke");
    return 0;
}
