// t424_user_fn_named_unsafe.nr — v0.3.149 regression fixture.
//
// Pre-v0.3.149, classify_kw mapped `unsafe` to a hard kw token (77)
// for the RFC-0003 `unsafe { ... }` block form. parse_primary's
// tt == 77 branch called parse_passthrough_block_expr which expects
// `{`. When the user wrote `unsafe(x)`:
//   1. parse_passthrough_block_expr saw `(`, printed two parse
//      errors ("expected token 52 got 50" then a cascade)
//   2. The build did NOT halt — codegen still emitted .ll, clang
//      still linked, the exe ran and returned 0 instead of the user
//      fn's result
//
// Same hazard class as v0.3.137-v0.3.142 contextual-kw silent
// miscompiles, but worse than the simple int_lit-0 default: this one
// produced LOUD parse-error output that adopters might assume halted
// the build. Adopters then ran the exe expecting a clean failure
// path, got a wrong-value path instead.
//
// `unsafe` is a common identifier name in any code that does
// system-level work, FFI wrappers, manual memory management, etc.
// (`unsafe(ptr)` for a deref, `unsafe(SomeType)` for a cast, etc.)
//
// Fix (v0.3.149): contextual kw. classify_kw stops mapping `unsafe`
// to 77. parse_primary's branch checks pkv lookahead -- only
// recognises the block form when next is `{`. The kw block form
// `unsafe { ... }` continues to work via the new check.
//
// Returns 42 = unsafe(41) = 41 + 1.

fn unsafe(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = unsafe(41);
    return r;
}
