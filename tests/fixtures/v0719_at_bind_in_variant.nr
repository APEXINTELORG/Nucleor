// v0.7.19 negative fixture — `@` binding inside variant pattern
// halts cleanly (was wrong-class NR020 expected `)`, got token 122).
fn main() -> i64 {
    let opt: Option<i64> = Some(7);
    match opt {
        Some(n @ 1..=10) => { print("in"); }
        _ => { print("other"); }
    };
    return 0;
}
