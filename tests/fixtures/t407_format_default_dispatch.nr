// t407_format_default_dispatch.nr — v0.3.131 regression fixture.
//
// Pins the `{}` default-spec heuristic dispatch in the format
// macro expander. Pre-v0.3.131, bare `{}` always called
// `int_to_str(arg)` regardless of the arg's actual type, so:
//
//   println!("{}", "hello")   →  "140699...."   (pointer address)
//   println!("{}", 3.14)      →  "4614253..."   (i64 bit pattern)
//
// HIGH-blast for adopters debugging with `println!("{}", v)` —
// the most common debug pattern — when v is a string or float.
//
// Heuristic dispatch (textual-only since the macro expander runs
// before parse, with no type info):
//   - quoted string literal `"..."`           → :s passthrough
//   - decimal numeric literal (has `.`)        → :f f64_to_str
//   - call to known float helper (sqrt(, exp(,
//     log(, tanh(, f64_*, f32_*)               → :f
//   - everything else                          → :i (back-compat)
//
// Adopters with typed `f64` variables should still write `{:f}`
// explicitly — the heuristic only corrects the obvious-from-text
// cases.
//
// Returns 0 when each form prints correctly. The verify gate
// captures stdout and asserts the lines match.

fn main() -> i64 {
    let s: str = format!("{}", "hello");
    if str_len(s) != 5 { return 1; };

    let f: str = format!("{}", 3.14);
    // "3.14" has length 4 (no trailing zeros under f64_to_str's
    // default "%g"-like format).
    if str_len(f) != 4 { return 2; };

    let i: str = format!("{}", 42);
    if str_len(i) != 2 { return 3; };

    return 0;
}
