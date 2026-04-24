// rods/pgs3 — verify rod wrapper compiles + links (v0.2.250 ship).
// Build-only smoke: a meaningful 3D pose-graph test needs ptr-based
// quaternion + info inputs which is fiddly in a one-shot Nucleor
// smoke. Correctness coverage in the direct C unit test (closed loop
// with rotated/translated edges + measurement noise; verifies
// Gauss-Newton reduces cost and recovers ground-truth poses).
import "stdlib/rods/pgs3.nr"

fn main() -> i64 {
    print("OK pgs3_smoke");
    return 0;
}
