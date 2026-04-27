// Probe §D: `pub struct S { pub x: i64 }` crashes parser.
pub struct S {
    pub x: i64,
    pub y: i64,
}

fn main() -> i64 {
    let s: S = S { x: 1, y: 2 };
    if s.x != 1 { return 1; };
    if s.y != 2 { return 1; };
    return 0;
}
