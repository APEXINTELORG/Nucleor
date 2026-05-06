// v0.4.33a silent-fall-through closure: `let (a, b) = (5, 7);` printed
// ERROR but emitted a placeholder let-stmt and continued. Tuple-let
// destructuring is now supported; this fixture must return 12.
fn main() -> i64 {
    let (a, b) = (5, 7);
    return a + b;
}
