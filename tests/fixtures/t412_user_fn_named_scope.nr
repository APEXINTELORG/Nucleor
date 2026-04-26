// t412_user_fn_named_scope.nr — v0.3.138 regression fixture.
//
// Pins user fns and call sites named `scope`. Pre-v0.3.138, `scope`
// was classified as a hard keyword (token 80) by the lexer because
// of a planned-but-never-implemented `scope { … }` block-form
// construct. The reservation was speculative — zero `scope { … }`
// usage existed in the entire codebase — but the kw classification
// still forced the lexer to refuse `scope` as an identifier.
//
//   1. `fn scope(x) { … }` — parse_fn_decl reads pkv at the kw
//      position and gets the string `"scope"`, so the fn was
//      registered correctly.
//   2. `scope(41)` at the call site — parse_primary had no branch
//      for token 80. Silent fall-through to the `int_lit 0` default
//      at the bottom of parse_primary. The call collapsed to a
//      constant 0 and the trailing `(41)` was eaten as garbage by
//      a downstream recovery path. NO diagnostic.
//
// Same hazard class as the v0.3.137 `pure` fix and the v0.3.126
// user-fn-shadows-runtime bug — silent dispatch failure under what
// looks like the right name. `scope` is a common identifier name
// (RAII helpers, scoped resource guards, parser combinators).
//
// Fix (v0.3.138): removed `scope` from classify_kw. The lexer emits
// identifier token 1 with value `"scope"`. The dead parse_stmts
// branch for `tt == 80 || tt == 81` was also removed (zero usage).
// Future RFCs that resurrect block-form `scope { … }` will need
// contextual lexing instead of hard kw classification.
//
// Returns 42 = scope(41) = 41 + 1, proving the call dispatched to
// the user fn instead of being eliminated to const 0.

fn scope(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = scope(41);
    return r;
}
