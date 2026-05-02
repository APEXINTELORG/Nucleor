// Regression: self-extending a 2-cell inline Vec must snapshot the
// original length before pushes migrate inline_data to heap storage.

fn main() -> i32 {
    let v: Vec<i64> = Vec::new();
    v.push(10);
    v.push(20);
    vec_extend(v, v);
    if v.len() != 4 { return 1; };
    if v[0] != 10 { return 2; };
    if v[1] != 20 { return 3; };
    if v[2] != 10 { return 4; };
    if v[3] != 20 { return 5; };
    print("OK vec_extend_self_inline");
    return 0;
}
