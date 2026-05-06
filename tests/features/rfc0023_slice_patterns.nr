// RFC-0023 — slice patterns on Vec. v0.4.169 regression-guard fixture.
// Exact-length slice patterns are supported today. `[a, b, c]` matches
// a 3-element Vec, `[single]` matches a 1-element Vec, and `[]` matches
// an empty Vec. Rest-binding slice patterns remain covered by the
// negative fixture until full rest matching lands.

fn main() -> i32 {
    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    let head_tail: i32 = match v {
        [a, middle, b] => a + middle + b, // matches: 10 + 20 + 30 = 60
        _          => 0,
    };
    if head_tail != 60 { return 1; };

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
