// hot.nr — @hot attribute, no heap/format/indirect call in body
@hot
fn dot(xs: Vec<i32>, ys: Vec<i32>, n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        acc = acc + vec_get(xs, i) * vec_get(ys, i);
        i = i + 1;
    };
    return acc;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let xs: Vec<i32> = Vec::new();
    let ys: Vec<i32> = Vec::new();
    let mut k: i64 = 0;
    while k < 5 {
        xs.push(k + 1);
        ys.push(k + 2);
        k = k + 1;
    };
    // 1*2 + 2*3 + 3*4 + 4*5 + 5*6 = 2 + 6 + 12 + 20 + 30 = 70
    if dot(xs, ys, 5) != 70 { print("FAIL hot: dot"); fail = fail + 1; };
    if fail == 0 { print("OK hot"); return 0; };
    return 1;
}
