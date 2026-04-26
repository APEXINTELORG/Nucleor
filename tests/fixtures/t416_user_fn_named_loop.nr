// t416_user_fn_named_loop.nr — v0.3.141 regression fixture.
//
// Pins user fns and call sites named `loop`. Same hazard class as
// the v0.3.137 `pure`, v0.3.138 `scope`/`spawn`, v0.3.139
// `requires`, v0.3.140 `restricts` fixes — `loop` was hard-classified
// as token 84 by the lexer for the canonical `loop { BODY }`
// stmt-form (which desugars to `while true { BODY }`). The kw form
// IS used (tests/lang/loop_kw.nr exercises it), but the kw branch
// lived in `parse_stmts` only. parse_primary had no branch for token
// 84, so any `loop(x)` call site in expression position fell through
// to the silent `int_lit 0` default and collapsed to constant 0 in
// the IR with no diagnostic.
//
// `loop` is a common identifier name (event loops, game loops,
// runloop helpers, control-flow utilities).
//
// Fix (v0.3.141): `loop` becomes contextual. classify_kw stops
// mapping it to 84. The parse_stmts branch that consumed
// `loop { BODY }` is rewritten to detect `pkv == "loop" &&
// pk(pos + 1) == 52` (i.e. `{`). The top-level kw-at-module-scope
// rejection is also updated to detect the contextual form.
//
// Returns 42 = loop(41) = 41 + 1.

fn loop(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = loop(41);
    return r;
}
