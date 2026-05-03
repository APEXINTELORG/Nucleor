// v0.6.84 RFC V1.4 (partial): #[derive(PartialEq)] auto-generates
// the helper fn `<Type>__derived_eq(a, b) -> i64`. Pre-fix
// the derive was silently dropped (DERIVE-001 warning) and
// adopters had to hand-write the field-walk fn. Post-fix the
// textual pre-pass `expand_derive_partialeq` walks the source,
// finds `#[derive(...PartialEq...)]` followed by a struct decl
// (named or tuple), and appends the eq helper at end of source.
//
// Auto-dispatch of `==`/`!=` to the helper is deferred to a
// follow-on V1.4 ship; this fixture exercises the manual call.
#[derive(PartialEq)]
struct Point { x: i64, y: i64 }

#[derive(Debug, PartialEq)]
struct Pair(i64, i64);

fn main() -> i32 {
    let a: Point = Point { x: 5, y: 7 };
    let b: Point = Point { x: 5, y: 7 };
    let c: Point = Point { x: 5, y: 8 };
    print_int(Point__derived_eq(a, b) as i32);   // 1
    print_int(Point__derived_eq(a, c) as i32);   // 0

    let p: Pair = Pair(1, 2);
    let q: Pair = Pair(1, 2);
    let r: Pair = Pair(1, 3);
    print_int(Pair__derived_eq(p, q) as i32);    // 1
    print_int(Pair__derived_eq(p, r) as i32);    // 0
    return 0;
}
