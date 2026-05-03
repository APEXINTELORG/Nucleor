// repro_v146_shift_var_rhs_runtime_panic.nr - v0.4.146.
// Pre-fix a non-literal shift RHS lowered to raw LLVM shl/ashr. If
// the runtime value was < 0 or >= 64, LLVM produced poison and the
// observed result was undefined. v0.4.75 caught literal RHS only.
//
// EXPECT: build succeeds, runtime panics with a clean shift message.
//
// v0.6.18 update: the new const-overflow folder tracks through `let mut`
// reassignment + simple arithmetic, so the prior shape `let mut amt = 1;
// amt = amt - 4;` now folds to -3 at compile time and fires NUM-008 at
// compile time instead of runtime. Use a fn parameter routed through a
// helper so the folder can't statically prove the shift amount.

fn shift_by(amt: i64) -> i64 {
    return 1 << amt;
}

fn main() -> i64 {
    let amt_str: str = "0";
    let amt: i64 = str_to_int(amt_str) - 4;
    let x: i64 = shift_by(amt);
    println!("{}", x);
    return 0;
}
