// t368_dyn_keyword_parse.nr — v0.3.92 regression fixture.
//
// Pins parser acceptance and the first type-check bridge for
// `Box<dyn Trait> = Box::new(Concrete)`.

trait Greet { fn hello(self) -> i64; }

#[repr(C)] struct A { n: i64 }
impl Greet for A { fn hello(self) -> i64 { return self.n; } }

// `dyn` in fn return type position — parser must accept syntactically
fn make_a() -> A { return A { n: 42 }; }

fn take_greet(_g: Box<dyn Greet>) -> i64 { return 5; }

fn main() -> i64 {
    let a: A = make_a();
    let _b: Box<dyn Greet> = Box::new(A { n: 7 });
    return a.hello() + take_greet(Box::new(A { n: 8 }));  // expect 47
}
