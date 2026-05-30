// EXPECT: build fails with single line containing MATCH-012.
// MATCH-012 — struct-pattern field after `:` must be an identifier
// (rename-binding form). Field-equality literal patterns deferred
// to v0.5+.
//
// v0.4.276: probe finding 2026-04-30 — pre-fix, the diag
// emitted twice (a clean error[MATCH-012]: line followed by a
// duplicate "PANIC: nucleor: MATCH-012..." line that polluted
// output). Folded into a single panic carrying the full diag
// text, matching MATCH-013's pattern.
//
// EXPECT: build fails with single line containing MATCH-012.

struct P { x: i32, y: i32 }

fn classify(p: P) -> i32 {
    match p {
        P { x: 0, y: 0 } => 0,
        P { x, y } => x + y,
    }
}

fn main() -> i32 {
    print_int(classify(P { x: 0, y: 0 }));
    0
}
