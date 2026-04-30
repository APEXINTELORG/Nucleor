// RFC-0023 — struct destructuring + same-name enum or-patterns.
// v0.4.169 regression-guard fixture. `Point { x, y }` binds the
// fields to the named locals; `Sign::Pos(n) | Sign::Neg(n) => n`
// captures the inner value across alternatives that bind the same
// name. Combined here in one fixture to keep the verify-suite
// step count tight.

struct Point { x: i32, y: i32 }

enum Sign {
    Pos(i32),
    Neg(i32),
}

fn main() -> i32 {
    let p: Point = Point { x: 3, y: 4 };
    let r: i32 = match p {
        Point { x, y } => x + y,    // matches: 7
    };
    if r != 7 { return 1; };

    let s: Sign = Sign::Pos(7);
    let v: i32 = match s {
        Sign::Pos(n) | Sign::Neg(n) => n,    // matches Pos branch: 7
    };
    if v != 7 { return 1; };

    let s2: Sign = Sign::Neg(42);
    let v2: i32 = match s2 {
        Sign::Pos(n) | Sign::Neg(n) => n,    // matches Neg branch: 42
    };
    if v2 != 42 { return 1; };

    print("OK rfc0023_struct_destructure");
    0
}
