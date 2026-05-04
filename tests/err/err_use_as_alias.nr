// EXPECT: nucleor: `use ... as ...` aliases not yet supported
// v0.7.18 - use aliases halt cleanly instead of importing the module while dropping the alias.
use std::strings as strings_alias;

fn main() -> i32 {
    return 0;
}
