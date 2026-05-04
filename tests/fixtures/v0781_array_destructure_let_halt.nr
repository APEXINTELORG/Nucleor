// v0.7.81 negative fixture — Rust array destructure-in-let halt.
// Pre-fix `let [a, b, c] = [1, 2, 3];` produced clang-link
// wrong-class `error[TYP-005]: undefined function 'a()'`: the
// LHS validator printed a "tuple destructuring assignment not
// supported" note but the build continued, emitted broken IR,
// and the first array element became a phantom fn call. Halt
// cleanly at parse-let.
//
// Sister to v0.6.61 struct-destructure-in-let and v0.3.81 tuple-
// destructure-in-let halts (same pattern-in-let family).
fn main() -> i64 {
    let [a, b, c] = [1, 2, 3];
    return a + b + c;
}
