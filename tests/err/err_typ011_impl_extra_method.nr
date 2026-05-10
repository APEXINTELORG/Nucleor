// EXPECT: error[TYP-008] is not a member of trait

trait Foo {
    fn one(self) -> i64;
}

struct P {
    v: i64,
}

impl Foo for P {
    fn one(self) -> i64 { self.v }
    fn extra(self) -> i64 { 42 }
}

fn main() -> i32 {
    let p: P = P { v: 5 };
    print_int(p.one() as i32);
    0
}
