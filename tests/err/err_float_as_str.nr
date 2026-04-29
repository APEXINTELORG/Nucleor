// EXPECT: error[NUM-023] `f64` cannot be `as`-cast to `str`
// v0.4.143: float / bool as-cast to `str` silently produced an
// invalid str pointer. `let s: str = x as str` for `x: f64`
// lowered to a no-op (the i64 cell holding the f64 bit pattern
// was reinterpreted as a char ptr); the next `print(s)` /
// `str_len(s)` dereferenced the bit pattern as a heap address
// and SIGSEGV'd. Same hazard for `bool as str` (i64=1 → reads
// memory at 0x1 → crash). The i*/u* -> str direction stays
// allowed (v0.4.72 i64-everywhere convention covers heap-pointer
// pun), but f* and bool sources have no such justification.
// s1-only fix.

fn main() -> i32 {
    let x: f64 = 3.14;
    let s: str = x as str;
    print(s);
    0
}
