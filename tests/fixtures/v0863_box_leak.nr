// v0.8.63 — Box::leak(b) pass-through acceptance.
// Pre-v0.8.63: hit the generic "unsupported associated-fn call Box::leak"
// PANIC. Post-fix: Box::leak is a no-op pass-through in Nucleor's i64-
// everywhere ABI (no automatic drop today; Box IS the inner pointer).
//
// Pattern 1: basic Box::leak returning &T
fn main() -> i64 {
    let b: Box<i64> = Box::new(42);
    let r: &i64 = Box::leak(b);
    let v: i64 = *r;

    // Pattern 2: Box<str> leak (string pointer)
    let sb: Box<str> = Box::new("hello");
    let sr: &str = Box::leak(sb);
    let slen: i64 = str_len(sr);

    // Pattern 3: Box<struct> leak
    // (value pass-through — struct stays reachable)
    let nb: Box<i64> = Box::new(99);
    let nr2: &i64 = Box::leak(nb);

    // Expected: v = 42, slen = 5
    return v + slen;
    // expected exit: 47
}
