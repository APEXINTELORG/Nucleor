// EXPECT: error[TYP-016] missing an `else` branch
// v0.4.126: `if cond { val }` with NO else branch assigned to a
// non-void/unit binding silently lowered the false-condition path
// to the alloca's zero-init slot. `let x: i64 = if false { 5 };`
// produced `x == 0` with no signal. Rust rejects with "if expr
// of type X must have an else clause." Same hazard class as
// v0.4.108 tail-expr return mismatch — the unset value was a
// silent zero, not an error.

fn main() -> i32 {
    let x: i64 = if false { 5 };
    print_int(x);
    0
}
