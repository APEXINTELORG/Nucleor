// t354_match_arm_return.nr — v0.3.79 regression fixture.
//
// Pins parser support for `return EXPR` / `break` / `continue`
// stmt-style match-arm bodies. Pre-v0.3.79, parse_match_stmt's
// arm-body handler accepted `{ stmts }` block form OR a single
// expression — but `return 42` is a statement, not an expression.
// The parser called parse_expr(`return 42`) which silently failed,
// leaving cp parked on `return`, producing the cascading
// "expected token 64 got 44/16" parse errors as the next arm's
// pattern-parse re-entered partway through the previous arm's body.
//
// Post-v0.3.79, the arm-body handler explicitly recognizes
// `return` (16), `break` (18), and `continue` (19) tokens and
// produces the corresponding stmt nodes (kind 22/26/27).
//
// Returns 0 on success; non-zero is which check failed.

enum Status { Ok, Err }
enum Maybe { Just(i64), Nothing }

fn use_status(s: Status) -> i64 {
    match s {
        Status::Ok => return 42,
        Status::Err => return 7,
    }
}

fn use_maybe(m: Maybe) -> i64 {
    match m {
        Maybe::Just(v) => return v,
        Maybe::Nothing => return 0,
    }
}

fn use_wildcard(s: Status) -> i64 {
    match s {
        Status::Ok => return 1,
        _ => return 99,
    }
}

fn main() -> i64 {
    if use_status(Status::Ok) != 42 { return 91; };
    if use_status(Status::Err) != 7 { return 92; };
    if use_maybe(Maybe::Just(123)) != 123 { return 93; };
    if use_maybe(Maybe::Nothing) != 0 { return 94; };
    if use_wildcard(Status::Err) != 99 { return 95; };
    return 0;
}
