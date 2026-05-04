// v0.8.33 — tuple destructure in let: `let (a, b) = expr;`
// Tests both anonymous-tuple RHS and named-tuple-struct RHS.

struct Pair(i64, i64);

fn make_pair(x: i64, y: i64) -> Pair {
    return Pair(x, y);
}

fn main() -> i64 {
    // Case 1: anonymous tuple literal RHS
    let (a, b) = (3, 4);
    // Case 2: named tuple-struct RHS from a fn call
    let (c, d) = make_pair(10, 20);
    // Case 3: three-element destructure
    let (x, y, z) = (1, 2, 3);
    // Case 4: wildcard binding (ignored field)
    let (p, _) = (7, 99);
    return a + b + c + d + x + y + z + p;
    // expected: 3+4+10+20+1+2+3+7 = 50
}
