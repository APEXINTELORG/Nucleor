// repro_v56_match_exhaustive_stmt_guard.nr
//
// v0.4.56 NUC-FEEDBACK silent-miscompute close — non-exhaustive
// match on enum (statement form) now halts at compile time with
// MATCH-001 instead of silently returning 0 for unmatched values.
//
// Pre-fix `match Color::Green { Color::Red => println!("red") };`
// silently no-op'd (the lower defaulted to 0 for unmatched). The
// MATCH-001 diagnostic was already in the error-tier code list but
// emitted at "warning" severity — so the build didn't halt.
//
// v0.4.56 promotes both MATCH-001 and the legacy TYP-001 alias to
// "error" severity. Workaround text added to the diagnostic.
//
// NOTE: this only covers MATCH-AS-STATEMENT. Match-as-expression
// (e.g. `let n: i64 = match c { ... };`) still escapes the check
// because `check_expr` lacks a kind-38 handler. Tracked for a
// follow-on ship that adds the same exhaustiveness check there.

enum Color { Red, Green, Blue, }

fn main() -> i64 {
    let c: Color = Color::Green;
    match c {
        Color::Red => println!("red"),     // MATCH-001 expected
    };
    return 0;
}
