// v0.7.58 positive fixture — enum where-clause now builds cleanly
// (was halt v0.7.57, was wrong-class NR020 pre-v0.7.57).
enum E<T> where T: Copy { A(T), B }
fn main() -> i64 {
    let e: E<i64> = E::A(5);
    match e { E::A(n) => print("a"), E::B => print("b") };
    return 0;
}
