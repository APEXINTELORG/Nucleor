// rods/ba — verify rod wrapper compiles + links (v0.2.252 ship).
// Build-only smoke: a meaningful BA test needs ptr-based camera +
// point + observation inputs which is fiddly in a one-shot Nucleor
// smoke. Correctness coverage in the direct C unit test (synthetic
// 5-camera / 20-point scene with perfect noise-free observations;
// verifies Gauss-Newton recovers ground-truth poses + points to
// machine precision).
import "stdlib/rods/ba.nr"

fn main() -> i64 {
    print("OK ba_smoke");
    return 0;
}
