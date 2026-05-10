// EXPECT: error[TYP-008] generic struct field initializer mismatch

struct Pair<A, B> {
    first: A,
    second: B,
}

fn main() -> i32 {
    let p: Pair<i32, i32> = Pair<i32, i32> { first: "x", second: 20 };
    print_int(p.second);
    0
}
