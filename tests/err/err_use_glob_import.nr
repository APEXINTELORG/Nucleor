// EXPECT: nucleor: `use ...::*` glob import not yet supported
// v0.7.18 - glob imports halt cleanly instead of building a wrong rewritten path.
use std::strings::*;

fn main() -> i32 {
    return 0;
}
