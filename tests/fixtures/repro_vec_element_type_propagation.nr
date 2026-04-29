fn main() -> i64 {
    let mut v: Vec<str> = Vec::new();
    v.push("red");
    let bad_index: i64 = v[0];
    let bad_get: i64 = vec_get(v, 0);
    let bad_first: i64 = v.first();
    return bad_index + bad_get + bad_first;
}
