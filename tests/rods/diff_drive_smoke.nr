// rods/diff_drive — verify rod wrapper compiles + links (v0.2.332 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (equal wheel speeds → straight; in-place spin = (v_l = -v_r);
// arc integration matches analytic constant-curvature trajectory).
import "stdlib/rods/diff_drive.nr"

fn main() -> i64 {
    print("OK diff_drive_smoke");
    return 0;
}
