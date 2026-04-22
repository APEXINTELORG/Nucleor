// 03_structs.nr — Structs, fields, and field assignment.
// Build: nuc build examples/03_structs.nr -o structs
// Run:   ./structs.exe

struct Point {
    x: i64,
    y: i64
}

struct Rect {
    top_left: Point,
    width: i64,
    height: i64
}

fn area(r: Rect) -> i64 {
    return r.width * r.height;
}

fn translate_x(p: Point, dx: i64) -> Point {
    let q: Point = Point { x: p.x + dx, y: p.y };
    return q;
}

fn str_from_int(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = "";
    let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 {
        let d: i64 = v - (v / 10) * 10;
        s = str_concat(str_substring("0123456789", d, d + 1), s);
        v = v / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn main() -> i64 {
    let p: Point = Point { x: 3, y: 4 };
    print(str_concat("p.x = ", str_from_int(p.x)));
    print(str_concat("p.y = ", str_from_int(p.y)));

    // Build a rectangle from a fresh Point so we don't move `p` away.
    let origin: Point = Point { x: p.x, y: p.y };
    let r: Rect = Rect { top_left: origin, width: 10, height: 6 };
    print(str_concat("rect area = ", str_from_int(area(r))));

    // Translate p by 7 along x.
    let q: Point = translate_x(p, 7);
    print(str_concat("q.x (translated by 7) = ", str_from_int(q.x)));

    // Field assignment on the original Point binding.
    let mut tweak: Point = Point { x: 0, y: 0 };
    tweak.x = 42;
    print(str_concat("tweak.x (after assign) = ", str_from_int(tweak.x)));

    return 0;
}
