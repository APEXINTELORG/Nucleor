// t363_struct_like_enum_variant.nr — v0.3.87 regression fixture.
//
// Pins struct-like enum variant construction: `EnumName::Variant
// { field: value, ... }`. Pre-v0.3.87, parse_primary's kind-12
// (Type::Method) branch only handled paren-args (`Variant(args)`)
// or no-args. The struct-init form `Variant { field: val }` was
// not recognized — the parser produced kind-12 with empty args
// and then re-parsed `{ r: 5 }` as a separate block expression,
// where `r` resolved as an undefined global symbol → clang link
// error `use of undefined value '@r'`.
//
// Post-v0.3.87, parse_primary detects the struct-init form,
// parses comma-separated `name: value` pairs, and produces a
// kind-12 with args in source order (field names discarded —
// users must write fields in declaration order).
//
// Returns 0 on success.

enum Shape { Circle { r: i64 }, Square { s: i64 } }

fn main() -> i64 {
    let c = Shape::Circle { r: 5 };
    let sq = Shape::Square { s: 7 };

    let r1: i64 = match c {
        Shape::Circle(rr) => rr,
        Shape::Square(ss) => ss,
    };
    if r1 != 5 { return 91; };

    let r2: i64 = match sq {
        Shape::Circle(rr) => rr,
        Shape::Square(ss) => ss,
    };
    if r2 != 7 { return 92; };

    // Tuple-style construction still works as a regression check:
    let c2 = Shape::Circle(99);
    let r3: i64 = match c2 {
        Shape::Circle(rr) => rr,
        Shape::Square(ss) => ss,
    };
    if r3 != 99 { return 93; };

    return 0;
}
