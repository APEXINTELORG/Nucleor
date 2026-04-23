// rods/rod_helpers — build-only smoke (v0.2.150 wrap)
// Functional test of vec_str_push / call_fn2 needs cross-rod plumbing
// not available in a single test file — exercise build/link only.
import "stdlib/rods/rod_helpers.nr"

fn main() -> i64 {
    print("OK rod_helpers_smoke");
    return 0;
}
