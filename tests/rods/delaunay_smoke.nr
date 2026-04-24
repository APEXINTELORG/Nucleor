// rods/delaunay — verify rod wrapper compiles + links (v0.2.305 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (4 corners of unit square → 2 triangles; circumcenter of right
// triangle is the midpoint of the hypotenuse; collinear points
// return 0 from circumcenter; sq+center → 4 triangles, center in
// every one).
import "stdlib/rods/delaunay.nr"

fn main() -> i64 {
    print("OK delaunay_smoke");
    return 0;
}
