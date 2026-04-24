// rods/wbc — verify rod wrapper compiles + links (v0.2.256 ship).
// Build-only smoke; a meaningful test needs Jacobian + target-rate
// pointer arrays via bit-cast doubles which is fiddly in a one-shot
// Nucleor smoke. Correctness coverage in the direct C unit test
// (3 cases: single full-rank task; redundant-arm regularization;
// 2-task tradeoff under weighting).
import "stdlib/rods/wbc.nr"

fn main() -> i64 {
    print("OK wbc_smoke");
    return 0;
}
