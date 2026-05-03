// EXPECT: anonymous tuple type field access not yet supported
// v0.6.79 RFC V1.11: anonymous-tuple field access must halt cleanly
// with the named tuple-struct workaround instead of falling through to
// a generic field-resolution diagnostic.
fn main() -> i32 {
    let pair: (i64, i64) = (5, 7);
    print_int(pair.0 as i32);
    return 0;
}
