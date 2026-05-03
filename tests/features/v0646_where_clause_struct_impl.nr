// v0646_where_clause_struct_impl.nr — v0.6.46 regression fixture.
//
// Closes probe finding 2026-05-02-where-clause-struct-and-impl-still-
// NR020. Pre-fix `struct Wrapper<T> where T: A { … }` and
// `impl<T> X { … }` both panicked NR020. v0.6.46 accepts both forms
// at parse time (bounds not yet wired through to method dispatch —
// forward-roadmap).
//
// EXPECT: builds + runs to print "6\n7\n".

trait A { fn a(self: &Self) -> i64; }
struct Wrapper<T> where T: A { inner: i64 }
struct X { v: i64 }
impl A for X { fn a(self: &X) -> i64 { self.v + 1 } }
impl<T> X { fn passthrough(self: &X) -> i64 { self.v + 2 } }

fn main() -> i32 {
    let x: X = X { v: 5 };
    print_int(x.a() as i32);            // 6
    print_int(x.passthrough() as i32);  // 7
    let _w: Wrapper<X> = Wrapper { inner: 99 };
    0
}
