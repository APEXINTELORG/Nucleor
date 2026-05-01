// RFC-0033 first-pass positive: function declarations, extern
// declarations, and fn-pointer type syntax accept trailing `with [...]`.

extern fn host_known(x: i64) -> i64 with [no_alloc, no_panic];

fn inc(x: i64) -> i64 with [no_alloc, no_panic] {
    return x + 1;
}

fn effectful_decl_only(x: i64) -> i64 with [Alloc, Panic] {
    return x;
}

fn takes_callback(cb: fn(i64) -> i64 with [no_panic], x: i64) -> i64 with [no_alloc] {
    return x;
}

fn main() -> i32 {
    let a: i64 = inc(41);
    let b: i64 = takes_callback(0, a);
    print_int(b);
    return 0;
}
