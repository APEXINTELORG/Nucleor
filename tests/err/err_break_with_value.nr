// EXPECT: nucleor: break-with-value not yet supported
// v0.6.57 — break-with-value halts cleanly at parse (was wrong-class NR024)
fn main() -> i32 {
    let r: i64 = loop { break 42; };
    return r as i32;
}
