enum E { A(i64), B(i64) }

fn main() -> i64 {
    let e: E = E::A(1);
    return match e {
        E::A(x) | E::B(y) => x,
    };
}
