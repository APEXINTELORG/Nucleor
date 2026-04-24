// rods/fsp — verify rod wrapper compiles + links (v0.2.254 ship).
// Build-only smoke; a meaningful test needs an `is_valid` callback
// pointer + bit-cast doubles which is fiddly in a one-shot Nucleor
// smoke. Correctness coverage in the direct C unit test (open-
// terrain reachability + obstacle-avoidance scenario).
import "stdlib/rods/fsp.nr"

fn main() -> i64 {
    print("OK fsp_smoke");
    return 0;
}
