// EXPECT: error[TYP-007] generic trait-bound method dispatch
// Conservative first-pass guard: without monomorphized generic fn bodies,
// `T: Show` method dispatch is only sound when exactly one concrete impl
// for the bound method exists in the program.

trait Show {
    fn show(self) -> i64;
}

struct A {
    v: i64,
}

struct B {
    v: i64,
}

impl Show for A {
    fn show(self) -> i64 {
        return self.v + 100;
    }
}

impl Show for B {
    fn show(self) -> i64 {
        return self.v + 200;
    }
}

fn get_show<T: Show>(x: T) -> i64 {
    return x.show();
}

fn main() -> i32 {
    let a: A = A { v: 1 };
    let got: i64 = get_show(a);
    print_int(got as i32);
    return 0;
}
