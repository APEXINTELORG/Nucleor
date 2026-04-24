// rods/icp_p2p — verify rod wrapper compiles + links (v0.2.301 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (planar source rotated/translated against itself + normals →
// recovers (R, t) to machine precision in <10 iterations).
import "stdlib/rods/icp_p2p.nr"

fn main() -> i64 {
    print("OK icp_p2p_smoke");
    return 0;
}
