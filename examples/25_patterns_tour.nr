//! Pattern matching tour.
//!
//! Single runnable program exercising every supported pattern form.
//! Compile with `nuc build examples/25_patterns_tour.nr` and run;
//! it should print 7 OK lines and exit 0.
//!
//! Demonstrates range patterns, or-patterns, pattern guards,
//! @-bindings, slice patterns, struct destructure, and same-name
//! enum or-patterns.

struct Point { x: i32, y: i32 }

enum Sign {
    Pos(i32),
    Neg(i32),
    Zero,
}

/// Range patterns: `1..=9`, `1..10`, half-open ranges.
fn classify_char(c: i64) -> str {
    match c {
        48..=57           => "digit",
        97..=122 | 65..=90 => "letter",
        32                => "space",
        _                 => "other",
    }
}

/// Pattern guards: `if cond` after pattern, evaluates only on match.
fn classify_score(x: i32) -> str {
    match x {
        n if n < 0    => "negative",
        n if n == 0   => "zero",
        n if n < 50   => "low",
        n if n < 80   => "medium",
        _             => "high",
    }
}

/// `@`-bindings capture matched value while range-checking.
fn squared_in_range(x: i32) -> i32 {
    match x {
        n @ 1..=10 => n * n,
        n @ 11..=99 => n,
        _          => -1,
    }
}

/// Slice patterns on Vec: `[a, b, c]`, `[single]`, `[]`.
fn slice_summary(v: Vec<i32>) -> i32 {
    match v {
        [a, middle, b] => a + middle + b,
        [single]   => single,
        []         => 0,
        _          => -1,
    }
}

/// Struct destructuring binds every field as a local.
fn point_sum(p: Point) -> i32 {
    match p {
        Point { x, y } => x + y,
    }
}

/// Same-name enum or-patterns let multiple variants share the binding.
fn sign_value(s: Sign) -> i32 {
    match s {
        Sign::Pos(n) | Sign::Neg(n) => n,
        Sign::Zero                  => 0,
    }
}

/// Combined: struct destructure plus guard for field equality.
fn point_origin_or_distance(p: Point) -> i32 {
    match p {
        Point { x, y } if x == 0 && y == 0 => 0,
        Point { x, y } => x + y,
    }
}

fn main() -> i32 {
    if str_eq(classify_char(48), "digit") == 0      { print("FAIL char digit"); return 1; };
    if str_eq(classify_char(97), "letter") == 0     { print("FAIL char letter"); return 1; };
    if str_eq(classify_char(32), "space") == 0      { print("FAIL char space"); return 1; };
    print("OK range patterns");

    if str_eq(classify_score(50), "medium") == 0    { print("FAIL guard medium"); return 1; };
    if str_eq(classify_score(0), "zero") == 0       { print("FAIL guard zero"); return 1; };
    if str_eq(classify_score(-5), "negative") == 0  { print("FAIL guard neg"); return 1; };
    print("OK pattern guards");

    if squared_in_range(5) != 25                     { print("FAIL @-binding squared"); return 1; };
    if squared_in_range(50) != 50                    { print("FAIL @-binding range"); return 1; };
    if squared_in_range(200) != -1                   { print("FAIL @-binding wildcard"); return 1; };
    print("OK @-bindings");

    let mut v: Vec<i32> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    if slice_summary(v) != 60                        { print("FAIL slice [a, b, c]"); return 1; };
    let mut v2: Vec<i32> = Vec::new();
    v2.push(7);
    if slice_summary(v2) != 7                        { print("FAIL slice [single]"); return 1; };
    let v3: Vec<i32> = Vec::new();
    if slice_summary(v3) != 0                        { print("FAIL slice []"); return 1; };
    print("OK slice patterns");

    let p: Point = Point { x: 3, y: 4 };
    if point_sum(p) != 7                              { print("FAIL struct destructure"); return 1; };
    print("OK struct destructure");

    if sign_value(Sign::Pos(7)) != 7                  { print("FAIL Pos or-binding"); return 1; };
    if sign_value(Sign::Neg(42)) != 42                { print("FAIL Neg or-binding"); return 1; };
    if sign_value(Sign::Zero) != 0                    { print("FAIL Zero variant"); return 1; };
    print("OK same-name enum or-patterns");

    let origin: Point = Point { x: 0, y: 0 };
    if point_origin_or_distance(origin) != 0          { print("FAIL guard-as-equality (origin)"); return 1; };
    let off: Point = Point { x: 3, y: 4 };
    if point_origin_or_distance(off) != 7             { print("FAIL guard-as-equality (off)"); return 1; };
    print("OK guard-as-equality");

    print("ALL OK 25_patterns_tour");
    0
}
