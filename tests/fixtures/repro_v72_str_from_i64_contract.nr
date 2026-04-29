// repro_v72_str_from_i64_contract.nr — v0.4.72 doc-#2 §5 P1.
// Pre-fix `fn str_from_int(n: i32)` body handled i64::MIN — signature
// lied since Nucleor's i64-everywhere ABI lets i64 values flow through
// the i32 param. v0.4.72 added `str_from_i64(n: i64)` as the truthful
// internal entry; `str_from_int` kept as wrapper for backward compat.
//
// This pin asserts the wrapper still works for adopter code (no
// regression) — the new str_from_i64 is internal-only (no get_rt_name
// surface), used by compiler internals.

fn main() -> i64 {
    println!("{}", str_from_int(0));         // 0
    println!("{}", str_from_int(42));        // 42
    println!("{}", str_from_int(-1));        // -1
    println!("{}", str_from_int(2147483647)); // i32::MAX
    return 0;
}
