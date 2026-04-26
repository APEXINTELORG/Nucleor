// t413_user_fn_named_spawn.nr — v0.3.138 regression fixture.
//
// Pins user fns and call sites named `spawn`. Same hazard as the
// sibling t412 (`scope`) — pre-v0.3.138, `spawn` was hard-classified
// as token 81 for a speculative `spawn { … }` block-form construct
// that had zero usage in the codebase. Any user fn or call site
// named `spawn` collapsed to silent `int_lit 0` in parse_primary.
//
// The runtime exposes `__nucleor_thread_spawn` and
// `__nucleor_async_spawn` for actual concurrency, but those are
// distinct symbols accessed via fn-call mapping in get_rt_name —
// the bare `spawn` keyword form was never wired beyond the lex
// classification.
//
// Returns 42 = spawn(41) = 41 + 1.

fn spawn(x: i64) -> i64 { return x + 1; }

fn main() -> i64 {
    let r: i64 = spawn(41);
    return r;
}
