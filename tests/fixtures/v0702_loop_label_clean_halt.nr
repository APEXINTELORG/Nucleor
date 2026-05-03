// v0.7.2 (defensive halt): canonical Rust loop labels
// `'outer: for ... { break 'outer; }` / `'lbl: loop { continue
// 'lbl; }` pre-fix surfaced as wrong-class `NR020: parse_primary
// cannot start expression at token kind 98` because token 98 is
// the lifetime/label token and parse_primary has no `'label:`
// prefix branch. Now halts cleanly with a boolean-flag workaround
// pointer. Negative fixture (compile rejects).
fn main() -> i32 {
    'outer: for i in 0..5 {       // ← halts: loop labels unsupported
        for j in 0..5 {
            if i + j > 3 {
                break 'outer;
            }
        }
    }
    return 0;
}
