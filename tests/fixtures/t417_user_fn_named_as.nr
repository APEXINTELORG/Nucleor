// t417_user_fn_named_as.nr — v0.3.142 regression fixture.
//
// Pins user fns and call sites named `as`. Same hazard class as
// the v0.3.137-v0.3.141 contextual-keyword silent-miscompute series
// (`pure`, `scope`, `spawn`, `requires`, `restricts`, `loop`).
//
// Pre-v0.3.142, `as` was hard-classified as token 86 by the lexer
// for the postfix cast operator (`x as T`, RFC-0015 phase 2). The
// cast operator IS used heavily, but it ALWAYS appears AFTER an
// expression — never at the start of a primary. parse_primary had
// no branch for token 86, so any user fn or call site named `as`
// (e.g. `as(41)` at the start of an expression) collapsed to silent
// `int_lit 0` in the IR with no diagnostic.
//
// Fix (v0.3.142): `as` becomes contextual. classify_kw stops mapping
// it to 86. The cast operator's parse_postfix_cast loop is rewritten
// to use pkv lookahead (`pk == 1 && pkv == "as"`). Both call-site
// usage and the cast operator continue to work.
//
// Returns 42 = as(41) = 41 + 1.

fn as(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = as(41);
    return r;
}
