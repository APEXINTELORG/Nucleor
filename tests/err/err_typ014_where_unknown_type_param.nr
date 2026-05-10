// EXPECT: error[TYP-008] where-clause references unknown type parameter

trait Foo {
    fn foo(self) -> i64;
}

fn run<T>(x: T) -> i64 where U: Foo {
    0
}

fn main() -> i32 {
    print_int(0);
    0
}
