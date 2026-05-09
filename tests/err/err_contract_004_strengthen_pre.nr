// EXPECT: CONTRACT-004 impl strengthens precondition (Liskov)
// Lane 3 (F-DIAG-006): CONTRACT-004 had no negative test.

trait Counter {
    fn step(self, n: i64) -> i64;
}

struct Foo { v: i64 }

impl Counter for Foo {
    #[require(n > 0)]
    #[require(n < 100)]
    fn step(self, n: i64) -> i64 {
        return self.v + n;
    }
}

fn main() -> i64 {
    let f: Foo = Foo { v: 1 };
    return f.step(10);
}
