// repro_v59_match_expr_exhaustive_guard.nr
//
// v0.4.59 NUC-FEEDBACK silent-miscompute close — non-exhaustive
// match in EXPRESSION context now halts with MATCH-001 at compile
// time, mirroring the v0.4.56 statement-form close.
//
// Pre-v0.4.59 `let n: i64 = match c { Color::Red => 1 };` over a
// non-Red value silently returned 0 because check_expr lacked a
// kind-38 handler — only check_stmt did the exhaustiveness check.
// Match-as-expression entirely escaped MATCH-001.
//
// v0.4.59 adds the same exhaustiveness check to check_expr's kind-38
// handler. Both paths now emit MATCH-001 at "error" severity with the
// same workaround hint.

enum Color { Red, Green, Blue, }

fn main() -> i64 {
    let c: Color = Color::Green;
    let n: i64 = match c {
        Color::Red => 1,                  // MATCH-001 expected (in expr context)
    };
    println!("{}", n);
    return 0;
}
