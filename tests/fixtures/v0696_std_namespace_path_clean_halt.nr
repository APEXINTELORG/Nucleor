// v0.6.96 (defensive halt): canonical Rust stdlib namespace path
// `std::mem::swap(...)`, `std::cmp::min(...)`,
// `std::collections::HashMap::new()`, etc. (3+ `::`-separated
// path components with leading `std`/`core`/`alloc`) pre-fix
// surfaced as wrong-class `NR020: parse_primary cannot start
// expression at token kind 46` after the parser desync'd on the
// second `::`. Now halts cleanly with per-helper workaround
// pointers (tmp swap, if-min, unqualified ctors). Negative fixture.
fn main() -> i32 {
    let mut a: i64 = 5;
    let mut b: i64 = 7;
    std::mem::swap(&mut a, &mut b);    // ← halts: stdlib path unsupported
    print_int(a as i32);
    return 0;
}
