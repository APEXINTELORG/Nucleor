// rods/ik_dls — verify rod wrapper compiles + links (v0.2.176 ship).
// Build-only smoke; full IK convergence test needs proper Vec<f64>
// plumbing not available in a single test file.
import "stdlib/rods/ik_dls.nr"

fn main() -> i64 {
    print("OK ik_dls_smoke");
    return 0;
}
