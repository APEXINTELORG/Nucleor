// EXPECT: error[TYP-020] `void`-typed expression
// v0.4.132: void-returning fn (print_int, print, etc.) used as
// an arithmetic / comparison operand silently coerced to 0 —
// adopters who confused side-effect-only fns with value-returning
// fns got wrong arithmetic with no signal. Pre-fix
// `5 + print_int(10)` printed 10 (print_int's side effect) then
// returned x=5 (5+0). Now halts at type-check with TYP-020 naming
// the void side. Catches arithmetic + comparison ops; logical
// && / || excluded since they short-circuit.

fn main() -> i32 {
    let x: i64 = 5 + print_int(10);
    print_int(x);
    0
}
