// rods/speculative — verify rod wrapper compiles + links (v0.2.124 orphan)
import "stdlib/rods/speculative.nr"

fn main() -> i64 {
    spec_seed(42);
    print("OK speculative_smoke");
    return 0;
}
