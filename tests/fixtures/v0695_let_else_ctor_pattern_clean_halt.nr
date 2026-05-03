// v0.6.95 (defensive halt): canonical Rust let-else
// `let Some(v) = opt else { return; };` (Rust 1.65+) and the
// sister ctor-pattern-in-let `let Some(v) = opt;` pre-fix
// surfaced as wrong-class `NR020: parse_primary cannot start
// expression at token kind 14` (the `else` keyword) or similar
// parser confusion after reading the ctor name as the binding
// name. Now halts cleanly with `if let` / `match` workaround
// pointers. Negative fixture (compile rejects).
fn main() -> i32 {
    let opt: Option<i64> = Some(42);
    let Some(v) = opt else {    // ← halts: ctor-pattern-in-let unsupported
        return 1;
    };
    print_int(v as i32);
    return 0;
}
