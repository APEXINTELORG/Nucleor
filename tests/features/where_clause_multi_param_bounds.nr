// Q3/Q4 guard: multi-trait and multi-param where clauses.
//
// Locks the parser surface for:
//   fn f<T, U>(...) where T: A + B + C, U: D
//
// This intentionally avoids bound-method dispatch in the body. The goal is to
// catch parser/bound-capture regressions without depending on future
// monomorphized generic dispatch work.

trait A { fn a(self) -> i64; }
trait B { fn b(self) -> i64; }
trait C { fn c(self) -> i64; }
trait D { fn d(self) -> i64; }

struct Left { v: i64 }
struct Right { v: i64 }

impl A for Left { fn a(self) -> i64 { self.v + 1 } }
impl B for Left { fn b(self) -> i64 { self.v + 2 } }
impl C for Left { fn c(self) -> i64 { self.v + 3 } }
impl D for Right { fn d(self) -> i64 { self.v + 4 } }

fn keep_left<T, U>(x: T, y: U) -> T where T: A + B + C, U: D {
    return x;
}

fn main() -> i32 {
    let l: Left = Left { v: 10 };
    let r: Right = Right { v: 20 };
    let kept: Left = keep_left(l, r);
    if kept.v != 10 { return 1; };
    print("OK where_clause_multi_param_bounds");
    return 0;
}
