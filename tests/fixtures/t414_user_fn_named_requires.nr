// t414_user_fn_named_requires.nr — v0.3.139 regression fixture.
//
// Pins user fns and call sites named `requires`. Same hazard class
// as the v0.3.137 `pure`, v0.3.138 `scope`/`spawn` fixes —
// `requires` was hard-classified as token 75 by the lexer because
// it's the RFC-0030 fn-decl annotation form
// (`fn foo() -> T requires [<predicate>]`). The annotation is rare
// in user code; the identifier collision is common (auth gates like
// `requires_admin(user)`, capability checks, type-class witness
// fns, parser combinators). Pre-v0.3.139, parse_primary had no
// branch for token 75 in expression position so any
// `requires(x)` call collapsed to silent `int_lit 0` in the IR.
//
// Fix (v0.3.139): `requires` becomes contextual. classify_kw stops
// mapping it to 75. The 4 fn-decl annotation checks
// (parse_fn_decl, parse_extern_fn, parse_trait_method,
// parse_impl_method) now use pkv lookahead to recognise the
// annotation form. Mirrored in nucleor_tools_suite.nr.
//
// Returns 42 = requires(41) = 41 + 1.

fn requires(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = requires(41);
    return r;
}
