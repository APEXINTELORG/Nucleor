// t357_tuple_let_diagnostic.nr — v0.3.81 negative regression fixture.
//
// Pre-v0.3.81, writing `let (a, b) = (5, 7);` segfaulted the compiler
// with ACCESS_VIOLATION — parse_let read `(` as a var name and
// downstream code crashed on a garbage string offset.
//
// Post-v0.3.81: clean diagnostic in parse_let with skip-to-semicolon
// recovery. Build does NOT segfault.

fn main() -> i64 {
    let (a, b): (i64, i64) = (5, 7);   // <-- pre: segfault, post: clean diag
    return 0;
}
