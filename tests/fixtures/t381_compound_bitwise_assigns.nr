// t381_compound_bitwise_assigns.nr — v0.3.105 regression fixture.
//
// Pins the bitwise/shift compound assigns `&=`, `|=`, `^=`, `<<=`,
// `>>=`. Pre-v0.3.105, only the arithmetic family `+= -= *= /= %=`
// (tokens 110-114) was lexed as compound-assign tokens. Writing
// `x &= 0x0f` lexed as `x` `&` `=` `0x0f` — the parser dropped the
// trailing `= 0x0f` silently and produced wrong values, with NO
// diagnostic. Same HIGH-blast silent-miscompute hazard class as
// the bare bitwise ops (v0.3.103) and shifts (v0.3.104).
//
// Implementation: new lexer tokens 117 (`&=`), 118 (`|=`),
// 119 (`^=`), 120 (`<<=`), 121 (`>>=`), all desugared in
// parse_stmt's compound-assign branch by mapping the op-token
// back to its bare-binop form (`&` `|` `^` `<<` `>>`) and letting
// the existing parse_bitwise / parse_shift tiers + tok_to_ir +
// emit_inst do the lowering.
//
// Returns 0 when all five compound assigns produce the right
// answer; non-zero diagnostic codes pinpoint which op miscomputed.

fn main() -> i64 {
    let mut a: i64 = 0xff;
    a &= 0x0f;
    if a != 15 { return 1; };

    let mut b: i64 = 1;
    b |= 4;
    if b != 5 { return 2; };

    let mut c: i64 = 0xff;
    c ^= 0x0f;
    if c != 240 { return 3; };

    let mut d: i64 = 1;
    d <<= 4;
    if d != 16 { return 4; };

    let mut e: i64 = 256;
    e >>= 4;
    if e != 16 { return 5; };

    return 0;
}
