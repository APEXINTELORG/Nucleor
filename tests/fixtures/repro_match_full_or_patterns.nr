enum E { A(i64), B(i64), C }

fn score(e: E) -> i64 {
    return match e {
        E::A(x) | E::B(x) => x + 10,
        E::C => 3,
    };
}

fn main() -> i64 {
    if score(E::A(2)) != 12 { return 91; };
    if score(E::B(5)) != 15 { return 92; };
    if score(E::C) != 3 { return 93; };
    return 0;
}
