// RFC-0029 phase 1 (v0.2.164) — str_intern returns a stable
// canonical pointer per unique input string. Identical inputs
// return the SAME pointer, so downstream comparisons can be
// pointer-equality (cheap) instead of byte-equality.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Two interns of the same content must return the same pointer.
    let a: str = str_intern("hello");
    let b: str = str_intern("hello");
    // Compare as i64 — pointer identity check.
    let pa: i64 = a as i64;
    let pb: i64 = b as i64;
    if pa != pb { fail = fail + 1; print("FAIL identical-content not identical-pointer"); };

    // Different content should return different pointers.
    let c: str = str_intern("world");
    let pc: i64 = c as i64;
    if pa == pc { fail = fail + 1; print("FAIL different-content shared a pointer"); };

    // The interned string still str_eq's the original.
    if str_eq(a, "hello") == 0 { fail = fail + 1; print("FAIL interned content mismatch"); };
    if str_eq(c, "world") == 0 { fail = fail + 1; print("FAIL interned 'world' mismatch"); };

    if fail == 0 { print("OK str_intern_basic"); };
    return fail;
}
