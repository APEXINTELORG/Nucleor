// v0.7.50 negative fixture — or-pattern in `if let` halts cleanly
// (was wrong-class NR020 expected `=`, got token 65 (pipe)).
fn main() -> i64 {
    let opt: Option<i64> = Some(5);
    if let Some(1) | Some(2) = opt { print("y"); };
    return 0;
}
