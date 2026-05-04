// v0.7.65 consolidated negative fixture — local-decl-in-fn-body halt
// family. Replaces 4 single-keyword fixtures (v0747 type-alias, v0755
// const, v0756 static, v0759 fn) with one file.
//
// All four halt at the same parse_stmt keyword-token check
// (`tt == 74` type / `tt == 73` const / ident-`static` / `tt == 10` fn).
// Each shape is independently triggered — the build aborts at the first
// halt encountered. To validate a different keyword, swap the body line.
//
// Module-level forms of all four work cleanly — only the fn-body local
// form is caught.
fn outer() -> i64 {
    // v0.7.47: local type alias  — `type Pair = (i64, i64);`
    // v0.7.55: local const       — `const N: i64 = 5;`
    // v0.7.56: local static      — `static N: i64 = 5;`
    // v0.7.59: local fn          — `fn inner() -> i64 { return 0; }`
    type Pair = (i64, i64);
    return 0;
}
fn main() -> i64 { return 0; }
