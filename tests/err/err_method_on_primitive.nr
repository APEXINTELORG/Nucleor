// EXPECT: error[TYP-007] receiver type has no method
// v0.4.107: TYP-007 primitive-receiver method guard. Pre-fix
// `let x: i64 = 5; x.no_such_method();` lowered through the
// kind==8 catch-all to `vec_no_such_method(x)` which the v0.4.106
// lift surfaced as `error[TYP-005]: undefined function
// 'vec_no_such_method()'`. The `vec_` prefix in the error was
// confusing -- the user's source said nothing about Vec.
// Post-fix the type_base_name primitive check fires before the
// `vec_` fallback and emits a method-targeted TYP-007 line.

fn main() -> i32 {
    let x: i64 = 5;
    let y: i64 = x.no_such_method();
    print_int(y);
    0
}
