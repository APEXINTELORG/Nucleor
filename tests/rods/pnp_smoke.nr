// rods/pnp — verify rod wrapper compiles + links (v0.2.233 ship).
// Build-only smoke; functional pose recovery needs allocated point
// + pixel buffers, non-trivial in a single test file. Correctness
// coverage in the direct C unit test (synthetic 3D-to-2D projection
// → recover the planted camera pose).
import "stdlib/rods/pnp.nr"

fn main() -> i64 {
    print("OK pnp_smoke");
    return 0;
}
