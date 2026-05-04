// EXPECT: nucleor: cold attribute not yet supported
// v0.7.18 - cold attributes halt cleanly instead of being silently dropped.
#[cold]
fn rare_path() -> i64 {
    return 7;
}

fn main() -> i32 {
    return rare_path() as i32;
}
