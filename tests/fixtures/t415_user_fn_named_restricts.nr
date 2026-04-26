// t415_user_fn_named_restricts.nr — v0.3.140 regression fixture.
//
// Pins user fns and call sites named `restricts`. Same hazard class
// as v0.3.137 `pure`, v0.3.138 `scope`/`spawn`, v0.3.139 `requires`.
//
// Pre-v0.3.140, `restricts` was hard-classified as token 76 by the
// lexer for a planned `restricts [...] { ... }` RFC-0030 contract
// block form. Zero usage of that form existed in the codebase but
// `parse_primary` had a token-76 branch that did
// `skip_bracket_list + parse_passthrough_block_expr`. When the user
// wrote `restricts(41)`:
//
//   1. `skip_bracket_list` looked for `[`, found `(`, returned pos
//      unchanged.
//   2. `parse_passthrough_block_expr` tried to parse `(41)` as a
//      `{ ... }` block. It didn't see `{` — it consumed the rest of
//      main's body as a phantom block expression instead.
//
// Result: silent miscompute. The IR for main shows a series of
// branches and stores into a phantom alloca, returning 0. NO
// diagnostic, no parse error, no warning.
//
// Fix: removed `restricts` from classify_kw and dropped the dead
// `tt == 76` branches in parse_primary and parse_stmts. Mirrored
// in nucleor_tools_suite.nr.
//
// Returns 42 = restricts(41) = 41 + 1.

fn restricts(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = restricts(41);
    return r;
}
