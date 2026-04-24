// rods/bicycle — verify rod wrapper compiles + links (v0.2.299 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (straight-line driving advances x by v*dt; circular driving with
// fixed steer traces an arc; RK4 closer to analytic circle than
// Euler at large dt).
import "stdlib/rods/bicycle.nr"

fn main() -> i64 {
    print("OK bicycle_smoke");
    return 0;
}
