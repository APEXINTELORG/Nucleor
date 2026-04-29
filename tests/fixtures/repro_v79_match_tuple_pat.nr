// repro_v79_match_tuple_pat.nr — v0.4.79 silent fall-through close.
// Pre-fix tuple destructure pattern in match arms (`(x, y) =>`)
// was unsupported but the parser printed a diagnostic and silently
// downgraded the pattern to `_` (wildcard). Result: the arm fired
// for ALL inputs because the wildcard always matches, not just
// for tuples. Current compiler accepts tuple-shaped patterns for Vec<T>;
// this fixture keeps the original wrong-scrutinee guard pinned.
//
// EXPECT: build fails (msg contains "tuple/slice pattern requires Vec<T>").

fn main() -> i64 {
    let n: i64 = 5;
    let s: str = match n {
        (x, y) => "tuple",
        _ => "other",
    };
    println!("{}", s);
    return 0;
}
