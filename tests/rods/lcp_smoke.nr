// rods/lcp — verify rod wrapper compiles + links (v0.2.255 ship).
// Build-only smoke; a meaningful test needs M/q matrix entries via
// bit-cast doubles which is fiddly in a one-shot Nucleor smoke.
// Correctness coverage in the direct C unit test (4 cases:
// classic non-negative LCP, box LCP at active bounds, single-contact
// rigid-body normal-impulse, friction pyramid linearization).
import "stdlib/rods/lcp.nr"

fn main() -> i64 {
    print("OK lcp_smoke");
    return 0;
}
