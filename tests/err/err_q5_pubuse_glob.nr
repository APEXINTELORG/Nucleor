// EXPECT: `pub use ...` re-exports are not yet supported
// Q5 lock-in — v0.8.22. `pub use crate::module::*;` halts
// cleanly with workaround pointer (import directly or wrap in
// pub fn).
pub use crate::nothing::*;

fn main() -> i64 {
    return 0;
}
