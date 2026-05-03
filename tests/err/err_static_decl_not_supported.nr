// EXPECT: ERROR: `static` items are not yet supported in Nucleor
//
// v0.6.21 (probe finding 2026-05-01-static-decl-accepted-but-not-lowered):
// pre-fix `static GREET: str = "hello";` at module scope was silently
// dropped at parse time — the parser didn't recognise `static` as a
// keyword and the module-item loop skipped it token-by-token. Use
// sites of `GREET` lowered as `@GREET` global references and clang
// link failed with the opaque `error: use of undefined value '@GREET'`.
//
// v0.6.21 fix: clean parse-time halt with workaround pointer
// (use `const` for literals or wrap in a fn for computed values).

static GREET: str = "hello";

fn main() -> i32 {
    print(GREET);
    return 0;
}
