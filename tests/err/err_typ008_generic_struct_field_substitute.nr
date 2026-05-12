// EXPECT: error[TYP-008]
// Regression gate Layer 2 F-007: Pair<i64, str>.second has type str.
struct Pair<A, B> { first: A, second: B }

fn main() -> i32 {
    let p: Pair<i64, str> = Pair<i64, str> { first: 10, second: "hi" };
    let s: i64 = p.second;
    print_int(s as i32);
    0
}
