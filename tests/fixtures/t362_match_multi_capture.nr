// t362_match_multi_capture.nr — v0.3.86 regression fixture.
//
// Pins multi-capture enum patterns: `EnumName::Variant(a, b, c)`.
// Pre-v0.3.86, the parser only read ONE binding then expected `)`,
// cascading into "expected token 51 got 44" parse errors and broken
// `@x` undefined-symbol IR. The lowering's match_bind_payloads
// helper already supported `|`-separated multi-bindings; v0.3.86
// updates the parser to produce that format.
//
// Returns 0 on success.

enum Pair { Both(i64, i64), Left(i64), Right(i64), Neither }

fn main() -> i64 {
    // Two-capture variant
    let p1: Pair = Pair::Both(10, 32);
    let r1: i64 = match p1 {
        Pair::Both(a, b) => a + b,
        Pair::Left(x) => x,
        Pair::Right(y) => y,
        Pair::Neither => 0,
    };
    if r1 != 42 { return 91; };

    // Single-capture variants still work (regression check)
    let p2: Pair = Pair::Left(99);
    let r2: i64 = match p2 {
        Pair::Both(a, b) => a + b,
        Pair::Left(x) => x,
        Pair::Right(y) => y,
        Pair::Neither => 0,
    };
    if r2 != 99 { return 92; };

    return 0;
}
