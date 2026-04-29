// EXPECT: error[NR025] unknown escape sequence
// v0.4.121: unknown escape sequences in string literals (e.g.
// `"a\zb"`) silently dropped the backslash and emitted the next
// char as-is — `"a\zb"` became `"azb"` with no signal. Adopters
// typo'ing escapes or pasting Rust raw-string content got silent
// miscomputed strings. Now halts at lex time with NR025. Three
// new escapes also recognized in this release: `\r`, `\0`, `\'`.

fn main() -> i32 {
    print("a\zb");
    0
}
