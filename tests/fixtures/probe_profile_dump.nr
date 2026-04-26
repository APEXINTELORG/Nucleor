// Probe: NUCLEOR_PROFILE=1 dumps per-helper call counts at exit.
fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 10 {
        v.push(i * 2);
        i = i + 1;
    };
    let mut sum: i64 = 0;
    let mut j: i64 = 0;
    while j < v.len() {
        sum = sum + v[j];
        j = j + 1;
    };
    println!("{}", sum);
    return 0;
}
