// repro_v207_dup_fn_param_halts.nr — v0.4.207 NAM-001.
//
// Pre-fix `fn add(a: i32, a: i32) -> i32 { a + a }` compiled clean.
// The second `a` silently shadowed the first, so `add(3, 5)`
// returned 10 (5+5) instead of the naive 8 — silent miscompute,
// no diagnostic, first argument unreachable inside the body.
//
// Fix: parse_fn_decl walks each new param against the already-parsed
// list and panics with NAM-001 on collision. Linear scan; param
// lists are small in practice.
//
// EXPECT: build fails with NAM-001.

fn add(a: i32, a: i32) -> i32 {
    a + a
}

fn main() -> i32 {
    print_int(add(3, 5));
    0
}
