// rods/cam — verify rod wrapper compiles + links (v0.2.274 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (project / unproject roundtrip with identity pose, distortion at
// principal-axis sample, K matrix sanity).
import "stdlib/rods/cam.nr"

fn main() -> i64 {
    print("OK cam_smoke");
    return 0;
}
