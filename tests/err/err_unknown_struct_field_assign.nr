// EXPECT: error[TYP-018] unknown field
// v0.4.131: assignment to unknown struct field. Sister to v0.4.129
// (read-side close) — that one fired in type_expr kind 9 for
// `let y: i64 = p.y;` but assignments go through kind 21 with
// kind 9 LHS, missing the v0.4.129 check. Pre-fix `p.y = 99`
// for `struct P { x: i64 }` lowered to `vec_set(p, -1, 99)` and
// OOB-panicked at runtime with no compile-time signal.

struct P { x: i64 }

fn main() -> i32 {
    let mut p: P = P { x: 5 };
    p.y = 99;
    print_int(p.x);
    0
}
