// v0.6.79 RFC V1.11 (defensive halt): anonymous-tuple field access
// `let p: (i64, i64) = (5, 7); p.0` pre-fix surfaced as the generic
// `cannot resolve field access type` diag — wrong class. Now halts
// at lower-time with a clean named-tuple-struct workaround pointer.
// This file is a NEGATIVE fixture (compile must reject); exercise
// is via the err-fixture harness.
fn main() -> i32 {
    let pair: (i64, i64) = (5, 7);
    print_int(pair.0 as i32);    // ← halts: anonymous tuple unsupported
    return 0;
}
