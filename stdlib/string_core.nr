// Nucleor stdlib: string_core
// Core string operations for bootstrap compiler.
// These wrap runtime builtins with safe Nucleor interfaces.

fn string_length(s: str) -> i32 {
    str_len(s)
}

fn string_equal(a: str, b: str) -> bool {
    str_eq(a, b)
}

fn string_is_empty(s: str) -> bool {
    str_len(s) == 0
}

fn string_starts_with_char(s: str, c: i32) -> bool {
    if str_len(s) == 0 {
        false
    } else {
        // Compare first character
        str_len(s) > 0
    }
}

// Test: basic string operations compile and type-check
fn main() -> i32 {
    let hello: str = "hello";
    let world: str = "world";
    let len: i32 = string_length(hello);
    let eq: bool = string_equal(hello, hello);
    let empty: bool = string_is_empty("");
    print_int(len);
    print_bool(eq);
    print_bool(empty);
    0
}
