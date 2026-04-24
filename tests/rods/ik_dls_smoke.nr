// rods/ik_dls — verify rod wrapper compiles + links (v0.2.176 ship).
// Build-only smoke; full IK convergence test needs proper Vec<f64>
// plumbing not available in a single test file.
//
// v0.2.199: also exercises the singularity-detection accessor —
// before any solve runs, the metric should be the sentinel value
// (we just verify the call links + returns something).
import "stdlib/rods/ik_dls.nr"

fn main() -> i64 {
    let _sing: i64 = ik_get_last_singularity_metric();
    print("OK ik_dls_smoke");
    return 0;
}
