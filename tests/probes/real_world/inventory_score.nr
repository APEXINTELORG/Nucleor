// PROBE-1 real-world driver: inventory scoring.
//
// Exercises (per PROBE-1 design intent):
//   - Control flow: if/else cascade + while loop
//   - Multi-arg fns: `score_item(name: str, qty: i64, weight: i64)`
//   - Struct definition + field access
//   - Vec literal + iteration
//   - String + integer interop
//
// This is intentionally NOT an `add(a, b) { return a + b; }` shape.
// It mimics what an adopter's first program looks like: a small
// domain task with inputs, a scoring/transform function, and an
// aggregate output.

struct Item {
    name: str,
    qty: i64,
    weight: i64,
}

fn classify(score: i64) -> str {
    if score >= 100 {
        return "A";
    } else if score >= 50 {
        return "B";
    } else if score >= 10 {
        return "C";
    } else {
        return "D";
    }
}

fn score_item(name: str, qty: i64, weight: i64) -> i64 {
    let raw: i64 = qty * weight;
    if str_eq(name, "premium") == 1 {
        return raw * 2;
    }
    return raw;
}

fn main() -> i32 {
    let items: Vec<i64> = Vec::with_capacity(3);
    let mut scores: Vec<i64> = Vec::new();
    scores.push(score_item("premium", 4, 25));
    scores.push(score_item("standard", 10, 8));
    scores.push(score_item("clearance", 2, 3));
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(scores) {
        let s: i64 = vec_get(scores, i);
        total = total + s;
        i = i + 1;
    }
    let label: str = classify(total);
    print(str_concat("total=", str_from_int(total)));
    print(str_concat("class=", label));
    return 0;
}
