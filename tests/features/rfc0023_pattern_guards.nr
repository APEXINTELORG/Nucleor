// RFC-0023 — pattern guards. v0.4.169 regression-guard fixture.
// Locks in the v0.4-era confirmation that `match x { n if cond => ..., _ => ... }`
// works end-to-end (parsing through codegen). Multiple guards in series
// fall through correctly to the first matching arm.

fn main() -> i32 {
    let x: i32 = 50;
    let r: i32 = match x {
        n if n < 0   => 1,
        n if n == 0  => 2,
        n if n < 100 => 3,
        _            => 4,
    };
    if r != 3 { return 1; };

    // Guard with binding scoped to the arm body.
    let y: i32 = 7;
    let s: i32 = match y {
        n if n > 100 => 0,
        n if n > 5   => n * 10,   // matches: returns 70
        _            => -1,
    };
    if s != 70 { return 1; };

    print("OK rfc0023_pattern_guards");
    0
}
