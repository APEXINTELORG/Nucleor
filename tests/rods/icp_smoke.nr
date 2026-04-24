// rods/icp — verify rod wrapper compiles + links (v0.2.223 ship).
// Build-only smoke; functional alignment needs allocated point-
// cloud buffers, non-trivial in a single test file. Correctness
// coverage in the direct C test (translated cube → recover the
// translation; rotated cube → recover the rotation).
import "stdlib/rods/icp.nr"

fn main() -> i64 {
    print("OK icp_smoke");
    return 0;
}
