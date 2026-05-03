// v0.6.87 RFC V1.4 ext: `str == str` and `String == String` now
// auto-dispatch to the runtime helpers `str_eq` / `string_eq`.
// Pre-fix v0.4.52 (str==) + v0.4.151 (String==) emitted the
// TYP-011 ptr-compare diag warning that the binop did integer-
// pointer compare and pointed at the manual workaround. Adopters
// writing canonical Rust `if a == b { ... }` shipped silently
// broken IR (two equal-bytes values at different heap addresses
// returned FALSE). Now lower_expr binop kind-4 op==30/31 detects
// str/String operands and routes to the runtime helper, identical
// architectural pattern to v0.6.85's struct-derived auto-dispatch.
fn make_str() -> str {
    return "hello";
}

fn main() -> i32 {
    let a: str = "hello";
    let b: str = "hello";
    let c: str = make_str();
    let d: str = "world";
    // Pre-v0.6.87: ptr-compare → 0 even for equal bytes.
    // Post-v0.6.87: str_eq dispatch.
    if a == b { print_int(11); } else { print_int(0); };
    if a == c { print_int(22); } else { print_int(0); };
    if a == d { print_int(0); } else { print_int(33); };
    if a != d { print_int(44); } else { print_int(0); };
    return 0;
}
