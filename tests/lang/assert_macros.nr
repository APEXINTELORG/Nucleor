// assert_macros.nr — RFC-0021: assert, assert_eq, assert_ne builtins
// These map to __nucleor_assert* runtime via the compiler's builtin
// name table; no extern fn decl needed at the user site.

fn main() -> i32 {
    assert(1);
    assert_eq(2 + 2, 4);
    assert_eq(40 * 0, 0);
    assert_ne(5, 6);
    assert_ne(0 - 1, 1);
    print("OK assert_macros\n");
    return 0;
}
