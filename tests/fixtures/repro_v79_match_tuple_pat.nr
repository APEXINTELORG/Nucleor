// repro_v79_match_tuple_pat.nr — v0.4.79 silent fall-through close.
// Pre-fix tuple destructure pattern in match arms (`(x, y) =>`)
// was unsupported but the parser printed a diagnostic and silently
// downgraded the pattern to `_` (wildcard). Result: the arm fired
// for ALL inputs because the wildcard always matches, not just
// for tuples. v0.4.79 promotes to compile-time panic.
//
// EXPECT: build fails (msg contains "tuple destructure pattern in match").

fn main() -> i64 {
    let n: i64 = 5;
    let s: str = match n {
        (x, y) => "tuple",
        _ => "other",
    };
    println!("{}", s);
    return 0;
}
