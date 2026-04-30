// RFC-0023 — @-bindings. v0.4.169 regression-guard fixture.
// `n @ <pattern> => ...` binds the matched value to `n` while still
// matching against the inner pattern. Combines with range patterns
// for "match-and-capture" idioms.

fn main() -> i32 {
    let x: i32 = 5;
    let r: i32 = match x {
        n @ 1..=10 => n,        // matches: returns 5
        _          => 0,
    };
    if r != 5 { return 1; };

    let y: i32 = 50;
    let s: i32 = match y {
        n @ 1..=10  => n,
        n @ 11..=99 => n * 2,   // matches: returns 100
        _           => 0,
    };
    if s != 100 { return 1; };

    print("OK rfc0023_at_bindings");
    0
}
