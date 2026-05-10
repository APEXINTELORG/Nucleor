// EXPECT: error[NR036] recursive type

struct A {
    b: B,
    v: i64,
}

struct B {
    a: A,
    w: i64,
}

fn main() -> i32 {
    print_int(0);
    0
}
