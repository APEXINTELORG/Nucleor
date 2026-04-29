// EXPECT: error[TYP-021] `void`-typed expression cannot initialize binding
// v0.4.136: bare-let RHS evaluating to void was silently bound as 0 —
// sister to v0.4.132 (binop void). The annotated form
// `let x: i64 = print_int(5);` already halts with TYP-008; the
// no-annotation form `let x = print_int(5);` sailed through every
// check because tstr is empty so the str_len(tstr) > 0 branch is
// skipped. Detect init_t == void at the kind-20 type-check site
// before that branch. Allows `let _ = void_call();` (idiomatic
// discard). Mirrored to nucleor_tools_suite.nr.

fn main() -> i32 {
    let x = print_int(5);
    print_int(x);
    0
}
