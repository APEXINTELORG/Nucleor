// repro_v49_or_patterns.nr
//
// v0.4.49 RFC-0023 partial — `A | B | C => body` or-patterns for
// int literals and wildcards.
//
// Pre-v0.4.49 the parser printed parse errors at each `|` token but
// continued silently; the build succeeded and the match returned the
// fall-through arm value (0 in this fixture) for every input. Adopters
// reaching for the canonical Rust idiom got a quiet wrong result.
//
// v0.4.49 collects OR'd patterns into a list, parses the body once,
// and emits one match arm per pattern (sharing the body + guard).
// Each per-pattern arm uses the existing single-pattern lower path,
// so the fix needs no codegen change beyond the parser.

fn check(x: i64) -> i64 {
    let r: i64 = match x {
        1 | 2 => 100,
        3 | 4 | 5 => 200,
        _ => 0,
    };
    return r;
}

fn main() -> i64 {
    let mut total: i64 = 0;
    total = total + check(1);    // +100
    total = total + check(2);    // +100
    total = total + check(3);    // +200
    total = total + check(4);    // +200
    total = total + check(5);    // +200
    total = total + check(99);   //   +0
    println!("{}", total);       // 800
    return total;
}
