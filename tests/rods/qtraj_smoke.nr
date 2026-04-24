// rods/qtraj — verify rod wrapper compiles + links (v0.2.253 ship).
// Build-only smoke; evaluating the polynomial via bit-cast doubles
// is fiddly in a one-shot Nucleor smoke. Correctness coverage in
// the direct C unit test (3-segment 1-D trajectory; verifies
// waypoints + boundary conditions are met exactly and snap is
// minimized).
import "stdlib/rods/qtraj.nr"

fn main() -> i64 {
    print("OK qtraj_smoke");
    return 0;
}
