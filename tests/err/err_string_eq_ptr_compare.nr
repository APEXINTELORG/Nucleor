// EXPECT: error[TYP-011] `String == String` does pointer comparison
// v0.4.151: String == String / String != String silently did
// pointer comparison (two equal-bytes Strings at different heap
// addresses returned FALSE). The v0.4.52 fix covered str==str
// but not String; v0.4.147 covered struct== but String is a
// built-in heap buffer (not a user-defined struct registered in
// `structs`). Both adopters of "compare two heap-allocated
// String values" got a silent wrong result. The runtime helper
// `__nucleor_string_eq` exists; this is the missing
// surface-level dispatch from `==` to it. Hint points at
// `s.eq(t)` (which routes through string_eq via the v0.4.124
// String method dispatch). s1-only (the kind-4 binop check is
// in s1's type_expr).

fn main() -> i32 {
    let s: String = String::new();
    let s2: String = String::new();
    if s == s2 { print_int(1); } else { print_int(0); };
    0
}
