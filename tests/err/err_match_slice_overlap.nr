// EXPECT: error[MATCH-009] slice pattern contains more than one `..` rest marker
fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    return match v {
        [a, .., b, ..] => a + b,
        _ => 0,
    };
}
