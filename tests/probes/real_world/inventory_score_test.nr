// PROBE-1 real-world test driver: same shape as inventory_score.nr but
// with #[test] annotations for the `nuc test` probe. Exercises the
// test harness path on a real-world-shaped program (control flow +
// multi-arg fn + struct + vec literal).

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

#[test]
fn test_classify_boundaries() {
    assert_eq(str_eq(classify(0), "D"), 1);
    assert_eq(str_eq(classify(9), "D"), 1);
    assert_eq(str_eq(classify(10), "C"), 1);
    assert_eq(str_eq(classify(49), "C"), 1);
    assert_eq(str_eq(classify(50), "B"), 1);
    assert_eq(str_eq(classify(99), "B"), 1);
    assert_eq(str_eq(classify(100), "A"), 1);
    assert_eq(str_eq(classify(10000), "A"), 1);
}

#[test]
fn test_score_premium_doubles() {
    assert_eq(score_item("premium", 4, 25), 200);
    assert_eq(score_item("standard", 4, 25), 100);
    assert_eq(score_item("clearance", 0, 99), 0);
}

#[test]
fn test_aggregate_score() {
    let mut scores: Vec<i64> = Vec::new();
    scores.push(score_item("premium", 4, 25));
    scores.push(score_item("standard", 10, 8));
    scores.push(score_item("clearance", 2, 3));
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(scores) {
        total = total + vec_get(scores, i);
        i = i + 1;
    }
    assert_eq(total, 286);
    assert_eq(str_eq(classify(total), "A"), 1);
}
