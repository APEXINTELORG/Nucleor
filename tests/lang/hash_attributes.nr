// hash_attributes.nr — RFC-0001/0021 #[...] attribute lex-time skip
// Forward-compatible: lexer accepts #[...] syntax for the future RT
// attribute family, test attribute, etc. Semantics ship in v0.3+;
// this test verifies the lexer accepts the syntax cleanly.
//
// v0.6.25 update: `#[cfg(...)]` removed from this positive test. v0.6.25
// hard-rejects `#[cfg(...)]` and `#[cfg_attr(...)]` at lex time with a
// loud halt + workaround pointer (closes probe finding 2026-05-01-cfg-
// attribute-silently-ignored). The negative form lives at
// `tests/err/err_cfg_attribute_not_supported.nr`. Other attributes
// (#[test], #[no_alloc], #[no_panic], #[deadline]) continue to be
// silently consumed by the lexer.

#[test]
fn ignored_at_compile() {
    // Attribute is stripped by the lexer; this fn currently behaves
    // like any other fn. Once RFC-0021 lands, the test driver picks
    // these up.
}

#[no_alloc]
#[no_panic]
#[deadline = 1000]
fn rt_function() -> i64 { return 42; }

fn main() -> i64 {
    let r: i64 = rt_function();
    if r != 42 { print("FAIL: rt_function\n"); return 1; };
    print("OK hash_attributes\n");
    return 0;
}
