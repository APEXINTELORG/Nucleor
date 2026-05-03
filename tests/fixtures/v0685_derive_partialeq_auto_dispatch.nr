// v0.6.85 RFC V1.4 (complete): #[derive(PartialEq)] now auto-
// dispatches `==` and `!=` to the helper fn. Pre-fix (v0.6.84
// ship) only generated `<Type>__derived_eq(a, b)` — adopters had
// to call it manually via `if Foo__derived_eq(a, b) == 1 { ... }`.
// Post-fix: lower_expr binop kind-4 op==30/31 detects the helper
// via `sym_get(__fnret_<Type>__derived_eq)` and routes the binop
// to a kind-7 call. != emits `1 - eq` so result stays canonical.
// type_expr's TYP-011 ptr-compare diag suppresses when the helper
// exists.
#[derive(PartialEq)]
struct Point { x: i64, y: i64 }

#[derive(PartialEq)]
struct Pair(i64, i64);

fn main() -> i32 {
    let a: Point = Point { x: 5, y: 7 };
    let b: Point = Point { x: 5, y: 7 };
    let c: Point = Point { x: 5, y: 8 };
    // == auto-dispatch.
    if a == b { print_int(11); } else { print_int(0); };
    if a == c { print_int(0); } else { print_int(22); };
    // != auto-dispatch.
    if a != c { print_int(33); } else { print_int(0); };

    let p: Pair = Pair(1, 2);
    let q: Pair = Pair(1, 2);
    let r: Pair = Pair(1, 3);
    if p == q { print_int(44); } else { print_int(0); };
    if p != r { print_int(55); } else { print_int(0); };
    return 0;
}
