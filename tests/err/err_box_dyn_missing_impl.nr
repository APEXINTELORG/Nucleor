// EXPECT: error[TYP-008] type mismatch for binding '_b'
// v0.4.117: Box<Concrete> only coerces to Box<dyn Trait> when
// Concrete has an explicit impl Trait block.

trait Greet { fn hello(self) -> i64; }

#[repr(C)] struct A { n: i64 }
#[repr(C)] struct B { n: i64 }

impl Greet for A { fn hello(self) -> i64 { return self.n; } }

fn main() -> i64 {
    let _b: Box<dyn Greet> = Box::new(B { n: 7 });
    return 0;
}
