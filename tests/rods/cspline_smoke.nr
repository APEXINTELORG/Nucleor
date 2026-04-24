// rods/cspline — verify rod wrapper compiles + links (v0.2.271 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (interpolation through known waypoints exact at waypoints,
// natural BC: 2nd deriv 0 at endpoints, monotone fit on a smooth
// function).
import "stdlib/rods/cspline.nr"

fn main() -> i64 {
    print("OK cspline_smoke");
    return 0;
}
