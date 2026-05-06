// EXPECT: EFF-001 str_concat
// Negative fixture for EFF-001 — pure fn calling string allocator.
//
// `str_concat` allocates a new heap string. Pre-v0.8.323 a pure fn
// that called str_concat passed cleanly. v0.8.323 (RFC-0063 Phase
// 1.5) detects the call and fires EFF-001 naming str_concat.
//
// Expected: error[EFF-001] mentioning str_concat.

pure fn impure_via_str_concat(a: str, b: str) -> str {
    return str_concat(a, b);
}

fn main() -> i64 {
    let s: str = impure_via_str_concat("hello", " world");
    return str_len(s);
}
