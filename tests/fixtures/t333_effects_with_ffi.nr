// RFC-0033 first-pass: extern `with [no_alloc]` feeds the existing
// RT-005 per-symbol safety list. host_safe must stay clean; host_unsafe
// must still warn when called from a no_alloc function.

extern fn host_safe(x: i64) -> i64 with [no_alloc];

extern fn host_unsafe(x: i64) -> i64;

fn rt_caller(x: i64) -> i64 with [no_alloc] {
    let a: i64 = host_safe(x);
    let b: i64 = host_unsafe(x);
    return a + b;
}

fn main() -> i64 {
    return 0;
}
