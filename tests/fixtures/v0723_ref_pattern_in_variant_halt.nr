// v0.7.23 negative fixture — `ref` binding mode inside variant pattern
// halts cleanly (was wrong-class NR020 expected `)`, got identifier).
fn main() -> i64 {
    let opt: Option<i64> = Some(5);
    match opt {
        Some(ref v) => { print("ref"); }
        None => { print("none"); }
    };
    return 0;
}
