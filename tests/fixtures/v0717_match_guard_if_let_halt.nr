// v0.7.17 — negative fixture: `if let` guard in match arm
//
// Pre-fix: `match x { n if let Some(v) = opt => ... }` produced wrong-class
// `error[NR020]: parse_primary cannot start an expression at token kind 11`
// because the guard parser called `parse_expr` with `let` as the first token
// and `parse_expr` has no `let` branch.
//
// Post-fix: the guard parser detects token-11 (`let`) after the `if` and
// halts cleanly with a hoist-above-match workaround pointer.
//
// Expected: compiler emits clean ERROR + PANIC (not NR020), exit non-zero.

// XFAIL: if let guard not yet supported

fn main() -> i64 {
    let n: i64 = 5;
    let flag: i64 = 1;
    match n {
        x if let Some(v) = flag => { return x; }
        _ => { return 0; }
    }
}
