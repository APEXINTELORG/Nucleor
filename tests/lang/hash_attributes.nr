// hash_attributes.nr — RFC-0001/0021 #[...] attribute lex-time skip
// Forward-compatible: lexer accepts #[...] syntax for the future RT
// attribute family, test attribute, etc. Semantics ship in v0.3+;
// this test verifies the lexer accepts the syntax cleanly.

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

#[cfg(target_os = "linux")]
fn linux_only() -> i64 { return 1; }

fn main() -> i64 {
    let r: i64 = rt_function();
    if r != 42 { print("FAIL: rt_function\n"); return 1; };
    print("OK hash_attributes\n");
    return 0;
}
