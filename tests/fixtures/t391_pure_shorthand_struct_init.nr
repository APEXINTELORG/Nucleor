// t391_pure_shorthand_struct_init.nr — v0.3.114 regression fixture.
//
// Pins pure-shorthand struct init in expression position — `P { x }`
// (single field) and `P { x, y }` (multi field). Pre-v0.3.114, the
// parse_primary disambiguator at the IDENT { lookahead only fired
// the struct-init branch when the inside was empty (`}`) or started
// with a named field (`IDENT :`). Pure-shorthand patterns
// (`IDENT ,` / `IDENT }`) fell through to the bare-identifier path,
// the trailing `{ ... }` was treated as a separate block expression,
// and the type identifier became an unresolved global ref:
//
//   error: use of undefined value '@P'
//
// Hard adoption blocker for any constructor that returns via the
// canonical Rust shorthand form (`fn make(x, y) -> P { P { x, y } }`).
//
// Disambiguation guard: only fire pure-shorthand recognition when
// the type identifier starts with an uppercase letter. Without this
// guard, `if foo { bar }` and `while x { y }` patterns misfire as
// the lowercase identifier in primary position looks like a struct
// name to the disambiguator. Rust convention reserves CamelCase
// (uppercase-first) for types, so the case check is a clean
// boundary that avoids touching the existing if/while/match grammar.
//
// Returns 7 = 3 + 4 from a multi-field shorthand constructor body
// returning P, plus the single-field shorthand `W { v }` round-trip.

struct P { x: i64, y: i64 }
fn make(x: i64, y: i64) -> P { P { x, y } }

struct W { v: i64 }

fn main() -> i64 {
    let p: P = make(3, 4);
    let v: i64 = 99;
    let w: W = W { v };
    if p.x + p.y != 7 { return 1; };
    if w.v != 99 { return 2; };
    return 7;
}
