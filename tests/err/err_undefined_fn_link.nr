// EXPECT: error[TYP-005] undefined function (lifted from clang link)
// v0.4.106: TYP-005 lifted from clang link error to clean diagnostic.
// Pre-fix `let x = nonexistent_function(42);` emitted a TYP-005
// warning at type-check then let clang fail with the cryptic
//   target/.../foo.ll:N:M: error: use of undefined value '@nonexistent_function'
// line. Post-fix lift_undefined_fn_link_errors scans the clang
// output, claims any unresolved-fn names not already lifted as
// MOD-003, and prints the spec-aligned TYP-005 line:
//   error[TYP-005]: undefined function `nonexistent_function()`. ...
// Negative gate verifies the readable diagnostic appears.

fn main() -> i32 {
    let x: i64 = nonexistent_function(42);
    print_int(x);
    0
}
