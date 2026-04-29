// repro_v88_str_method_dispatch.nr — v0.4.88 dispatch-name fix.
// Pre-fix `s.len()` for `s: str` lowered to `vec_len(s)` which
// reads the str pointer as if it were a Vec header — silent
// miscompute, returned garbage like 1684828783 instead of byte
// length. Same hazard for `s.contains/replace/split/starts_with/
// ends_with` which failed at clang link with `undefined value
// '@vec_contains'` etc. v0.4.88 adds str-receiver-type-aware
// dispatch (mirrors the v0.3.100 HashMap/HashSet pattern).
//
// EXPECT: build succeeds + runtime output 12 (correct byte len).

fn main() -> i64 {
    let s: str = "hello, world";
    println!("{}", s.len());
    return 0;
}
