// rods/kdt — verify rod wrapper compiles + links (v0.2.251 ship).
// Build-only smoke: a meaningful k-NN test needs ptr-based output
// buffers + bit-cast doubles which are fiddly in a one-shot Nucleor
// smoke. Correctness coverage in the direct C unit test (random
// 3D point cloud, brute-force vs KD-tree comparison, k-NN ordering
// + non-uniform-density stress).
import "stdlib/rods/kdt.nr"

fn main() -> i64 {
    print("OK kdt_smoke");
    return 0;
}
