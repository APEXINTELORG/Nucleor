// EXPECT: error[TYP-008] does not match the trait method signature

trait Foo {
    fn op(self, x: i64) -> i64;
}

struct P {
    v: i64,
}

impl Foo for P {
    fn op(self, x: str) -> i64 { self.v }
}

fn main() -> i32 {
    let p: P = P { v: 5 };
    print_int(p.op("hi") as i32);
    0
}
