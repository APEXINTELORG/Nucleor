// EXPECT: enum or path pattern in `let`

enum Pair {
    P(i64, i64),
}

fn main() -> i32 {
    let p: Pair = Pair::P(10, 20);
    let Pair::P(a, b) = p;
    print_int(0);
    0
}
