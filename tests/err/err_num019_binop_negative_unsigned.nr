// EXPECT: error[NUM-019] expression evaluates to negative value
// err_num019_binop_negative_unsigned — v0.6.45 negative fixture
// closes probe finding 2026-05-01-num-019-coverage-gap-binop-vs-
// literal. Pre-fix `let a: u32 = 0 - 5;` evaded NUM-019 because
// the kind-5 (unary minus) check only matched `let a: u32 = -5;`.
// The kind-4 binop form const-folds to -5 at compile time but
// the unsigned-negative check didn't see it. v0.6.45 uses
// const_i64_expr to fold and check for negative values when the
// binding is unsigned.
//
// EXPECT: NUM-019 fires; build halts.

fn main() -> i32 {
    let a: u32 = 0 - 5;
    print_int(a as i32);
    0
}
