// EXPECT: error[MATCH-001] bool literal arm
// v0.4.134: bare `true`/`false` arms in `match` were parsed by the
// catch-all default branch in parse_match_arm as `__wild` arms with
// binding="true"/"false" — silently matching ANY value of any type
// and returning the body for ALL inputs. `match false { true => 1 }`
// returned 1 with no signal. Now halts at type-check via the
// kind 38 (match-as-expr) post-walk pass directing the user to
// `if cond { } else { }` for two-way bool branching.

fn main() -> i32 {
    let b: bool = false;
    let r: i64 = match b { true => 1 };
    print_int(r);
    0
}
