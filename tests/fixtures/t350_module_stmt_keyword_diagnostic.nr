// t350_module_stmt_keyword_diagnostic.nr — v0.3.75 negative regression fixture.
//
// Verifies that statement-level keywords at module scope produce a
// clear diagnostic. Pre-v0.3.75, the parser silently dropped these
// declarations token-by-token. v0.3.75 catches the eight common
// statement-level keywords (`if`, `while`, `return`, `break`,
// `continue`, `for`, `match`, `loop`) at the top-level dispatch
// and surfaces a uniform diagnostic.
//
// This fixture is intended to FAIL compilation; the verify-gate
// step asserts that the diagnostic text appears in stderr.

return 5;

fn main() -> i64 {
    return 0;
}
