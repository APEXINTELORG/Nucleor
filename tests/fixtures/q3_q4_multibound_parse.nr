// Q3 + Q4 lock-in (v0.8.22) — multi-trait + multi-param where
// clause parsing. The 3-trait bound `T: A + B + C` and the
// multi-param where `where T: A, U: B` both parse; the prior
// probe hit TYP-007 on `&T` method dispatch, which is a separate
// downstream concern. This fixture exercises the bound-parser
// without tripping the receiver-type issue.

trait A { fn aa() -> i64; }
trait B { fn bb() -> i64; }
trait C { fn cc() -> i64; }

fn use_three<T: A + B + C>() -> i64 { return 0; }

fn use_pair<T, U>() -> i64 where T: A, U: B { return 0; }

fn use_three_where<T>() -> i64 where T: A + B + C { return 0; }

fn main() -> i64 {
    return 0;
}
