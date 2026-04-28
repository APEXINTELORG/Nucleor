// repro_v60_undefined_fn_warn.nr
//
// v0.4.60 NUC-FEEDBACK silent-undefined-symbol guard. Closes
// deferred item #2 from the queue.
//
// Pre-fix `let x: i64 = nonexistent_function(42);` silently emitted
// `call i64 @nonexistent_function(...)` and failed late at clang
// link with `undefined value '@nonexistent_function'`. v0.4.60
// emits a warning-tier TYP-005 at type-check naming the call
// (still halts the build at clang for truly-undefined fns).
//
// Filters in place to suppress false positives:
//   1. Skip if callee starts with `__` (compiler-generated like
//      `__closure_N` or `__nucleor_capture_get`)
//   2. Skip if first character is uppercase (Type-prefixed names,
//      mostly via kind 12 anyway)
//   3. Skip if `sym_get(env, callee) >= 0` (registered variable
//      holding a fn-pointer)
//
// Severity is "warning" not "error" so cross-module privatized fns
// (which fail at type-check but get cleanly upgraded to MOD-003 by
// priv_lift_link_errors) still get the canonical MOD-003 diagnostic.

fn main() -> i64 {
    let x: i64 = nonexistent_function(42);   // TYP-005 warning expected
    println!("{}", x);
    return 0;
}
