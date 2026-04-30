// RFC-0023 — slice patterns on Vec. v0.4.169 regression-guard fixture.
// `[a, .., b]` matches a Vec with at least 2 elements and binds the
// first to `a`, the last to `b`. `[single]` matches a 1-element Vec.
// `[]` matches an empty Vec.

fn main() -> i32 {
    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    let head_tail: i32 = match v {
        [a, .., b] => a + b,    // matches: 10 + 30 = 40
        _          => 0,
    };
    if head_tail != 40 { return 1; };

    let mut v2: Vec<i32> = Vec::new();
    v2.push(7);
    let single: i32 = match v2 {
        [s] => s,                // matches: 7
        _   => 0,
    };
    if single != 7 { return 1; };

    let v3: Vec<i32> = Vec::new();
    let empty: i32 = match v3 {
        [] => 99,                // matches: 99
        _  => 0,
    };
    if empty != 99 { return 1; };

    print("OK rfc0023_slice_patterns");
    0
}
