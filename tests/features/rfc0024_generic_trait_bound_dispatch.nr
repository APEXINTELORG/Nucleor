// RFC-0024 generic-T trait-bound method dispatch.
//
// Probe-agent finding 2026-05-01-generic-T-trait-bound-method-dispatch:
// pre-fix, the generic body kept receiver `x` typed as `T`, so
// lower_expr kind-8 could not find `A__show` and fell through to the
// synthetic `vec_show(x)` fallback.

trait Show {
    fn show(self) -> i64;
}

struct A {
    v: i64,
}

impl Show for A {
    fn show(self) -> i64 {
        return self.v + 100;
    }
}

fn get_show<T: Show>(x: T) -> i64 {
    return x.show();
}

fn main() -> i32 {
    let a: A = A { v: 1 };
    let got: i64 = get_show(a);
    if got != 101 {
        print("FAIL generic trait-bound dispatch");
        return 1;
    };
    print("OK generic trait-bound dispatch");
    return 0;
}
