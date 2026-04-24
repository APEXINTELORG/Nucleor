// rods/dtw — verify rod wrapper compiles + links (v0.2.272 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (identical sequences → 0 distance; time-shifted sequences → low
// DTW vs high Euclidean; band-restricted matches the unbounded
// version when band is wide enough).
import "stdlib/rods/dtw.nr"

fn main() -> i64 {
    print("OK dtw_smoke");
    return 0;
}
