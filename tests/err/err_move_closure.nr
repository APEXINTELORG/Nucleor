// EXPECT: nucleor: `move` closure form not yet supported
// v0.6.62 — `move ||` / `move |args|` closure capture halts cleanly at parse
fn main() -> i32 {
    let n: i64 = 5;
    let f = move || n + 1;
    return f() as i32;
}
