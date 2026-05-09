// EXPECT: CONTRACT-005 impl weakens postcondition (Liskov)
// Lane 3 (F-DIAG-006): CONTRACT-005 had no negative test.

trait Bumper {
    #[ensure(result >= 0)]
    fn bump(self, n: i64) -> i64;
}

struct Bar { v: i64 }

impl Bumper for Bar {
    fn bump(self, n: i64) -> i64 {
        return self.v + n;
    }
}

fn main() -> i64 {
    let b: Bar = Bar { v: 1 };
    return b.bump(10);
}
