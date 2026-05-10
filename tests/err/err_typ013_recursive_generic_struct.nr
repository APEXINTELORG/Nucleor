// EXPECT: error[NR036] recursive type

struct Wrap<T> {
    inner: Wrap<T>,
}

fn main() -> i32 {
    print_int(0);
    0
}
