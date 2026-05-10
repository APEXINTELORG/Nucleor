// EXPECT: error[TYP-005] wrong number of type arguments

struct Pair<A, B> {
    first: A,
    second: B,
}

fn main() -> i32 {
    let p: Pair<i32> = Pair<i32> { first: 10, second: 20 };
    print_int(p.second);
    0
}
