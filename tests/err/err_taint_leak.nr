// Error test: tainted data cannot flow to clean context without sanitize
fn get_input() -> tainted<i32> {
    99
}

fn clean_sink(x: i32) -> i32 {
    x + 1
}

fn main() -> i32 {
    let dirty: tainted<i32> = get_input();
    // This must fail — tainted<i32> cannot pass where i32 is expected
    let result: i32 = clean_sink(dirty);
    result
}
