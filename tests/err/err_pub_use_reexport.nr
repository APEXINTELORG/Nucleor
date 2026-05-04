// EXPECT: nucleor: `pub use` re-export not yet supported
// v0.7.18 - pub use re-exports halt cleanly instead of being ignored.
pub use std::strings::*;

fn main() -> i32 {
    return 0;
}
