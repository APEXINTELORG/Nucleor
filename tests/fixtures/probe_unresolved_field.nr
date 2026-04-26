// Probe: deliberately unresolved field access
fn main() -> i64 {
    let x: i64 = 5;
    // x is not a struct so .nonexistent_field can't resolve
    let y: i64 = x.nonexistent_field;
    return y;
}
