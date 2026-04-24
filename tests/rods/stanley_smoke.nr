// rods/stanley — verify rod wrapper compiles + links (v0.2.298 ship).
// Build-only smoke; correctness coverage in the direct C unit test
// (front axle left-of-path → steers right; on-path aligned →
// steer ≈ 0; heading-only error → steer = ψ_e).
import "stdlib/rods/stanley.nr"

fn main() -> i64 {
    print("OK stanley_smoke");
    return 0;
}
