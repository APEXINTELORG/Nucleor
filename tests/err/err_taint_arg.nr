// Error test: tainted<i32> cannot be passed where i32 is expected
fn clean_sink(x: i32) -> i32 {
    x + 1
}

fn main() -> i32 {
    let dirty: tainted<i32> = 42;
    // Must fail — clean_sink expects clean i32
    clean_sink(dirty)
}
