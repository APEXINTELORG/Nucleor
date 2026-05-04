// v0.7.69 negative fixture — Rust `?Sized` opt-out trait bound halt.
// Pre-fix `<T: ?Sized>` parsed silently (the `?` was dropped, then
// `Sized` was stored as a normal bound), so adopter intent that the
// param accept DSTs was lost. Nucleor has no DST substrate today; the
// halt now points at the workaround (drop the bound).
fn foo<T: ?Sized>(x: T) -> i64 {
    return 1;
}

fn main() -> i64 { return 0; }
