// Q1 lock-in (v0.8.21) — exclusive range pattern in match arms.
// `match x { 0..10 => ... }` works correctly (matches [0, 10)
// half-open) — locked here so future refactors don't regress
// the boundary semantics.

fn cls(x: i64) -> i64 {
    return match x {
        0..10 => 1,    // [0, 10) exclusive of 10
        10 => 2,       // exact 10
        _ => 3,
    };
}

fn main() -> i32 {
    if cls(0) != 1 { return 1; };
    if cls(5) != 1 { return 2; };
    if cls(9) != 1 { return 3; };
    if cls(10) != 2 { return 4; };  // boundary: 10 must NOT match 0..10
    if cls(11) != 3 { return 5; };
    if cls(-1) != 3 { return 6; };
    return 0;
}
