// v0.6.94 (defensive halt): canonical Rust range expression at
// expression position (`let r = 0..10;` or `(0..10).step_by(2)`)
// pre-fix surfaced as wrong-class `error[NR020]: parse_primary
// cannot start an expression at token kind 58` because Nucleor
// only recognises ranges in for-loop heads (`for i in 0..10`).
// Now halts cleanly with a while-loop workaround pointer.
// Negative fixture (compile rejects).
fn main() -> i32 {
    let r = 0..10;     // ← halts: range-at-expression-position unsupported
    print_int(0);
    return 0;
}
