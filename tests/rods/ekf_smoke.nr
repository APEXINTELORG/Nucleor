// rods/ekf — verify rod wrapper compiles + links (v0.2.227 ship).
// Build-only smoke; functional filtering needs dynamics + measurement
// callbacks, non-trivial in a single test file. Correctness coverage
// in the direct C unit test (1D position+velocity tracker that
// converges on simulated noisy measurements).
import "stdlib/rods/ekf.nr"

fn main() -> i64 {
    let e: i64 = ekf_new(2, 1, 0);
    if e == 0 { print("FAIL ekf_new"); return 1; };
    ekf_free(e);
    print("OK ekf_smoke");
    return 0;
}
