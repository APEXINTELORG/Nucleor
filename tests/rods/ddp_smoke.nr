// rods/ddp — verify rod wrapper compiles + links (v0.2.249 ship).
// Build-only smoke; functional optimization needs dynamics + cost
// callbacks, both non-trivial in a single test file. Correctness
// coverage in the direct C unit test (1D double-integrator
// regulator + cart-pole-style nonlinear dynamics where DDP's
// Hessian terms actually matter).
import "stdlib/rods/ddp.nr"

fn main() -> i64 {
    print("OK ddp_smoke");
    return 0;
}
