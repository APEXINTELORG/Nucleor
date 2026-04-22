// Phase 5b: Generic struct with monomorphization

struct Pair<A, B> {
    first: A,
    second: B,
}

fn main() -> i32 {
    let p: Pair<i32, i32> = Pair<i32, i32> { first: 10, second: 20 };
    let sum: i32 = p.first + p.second;
    print_int(sum);
    0
}
