// v0.7.36 positive fixture — `todo!()` and `unimplemented!()` expand
// to canonical Rust-stdlib panic messages ("not yet implemented" /
// "not implemented") matching std::macros::todo / unimplemented.
// Pre-v0.7.36 the strip-and-pass path produced a `todo()` /
// `unimplemented()` fn call that failed with wrong-class TYP-005.
fn h_todo() { todo!(); }
fn h_unimpl() { unimplemented!(); }
fn main() -> i64 {
    print("OK v0.7.36 todo + unimplemented expand to panic");
    return 0;
}
