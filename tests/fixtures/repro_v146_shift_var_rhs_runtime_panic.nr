// repro_v146_shift_var_rhs_runtime_panic.nr - v0.4.146.
// Pre-fix a non-literal shift RHS lowered to raw LLVM shl/ashr. If
// the runtime value was < 0 or >= 64, LLVM produced poison and the
// observed result was undefined. v0.4.75 caught literal RHS only.
//
// EXPECT: build succeeds, runtime panics with a clean shift message.

fn main() -> i64 {
    let mut amt: i64 = 1;
    amt = amt - 4;
    let x: i64 = 1 << amt;
    println!("{}", x);
    return 0;
}
