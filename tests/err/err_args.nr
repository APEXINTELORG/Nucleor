// EXPECT: TYP-005 wrong number of arguments
// `add` takes (a: i32, b: i32) but is called with 1 arg.
// The type checker fires TYP-005 ("wrong number of arguments
// for 'add'") at the call site.
fn add(a: i32, b: i32) -> i32 { a + b }
fn main() -> i32 { add(1) }
