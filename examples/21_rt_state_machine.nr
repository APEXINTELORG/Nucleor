// 21_rt_state_machine.nr — Bounded-recursion state walk
// demonstrating the v0.3.9 `#[max_depth = N]` opt-out for
// the RT-008 recursive-call check.
//
// State-machine and trajectory-planner code routinely
// recurses by design (tree walk, iterative-deepening,
// ladder-logic resolver, behavior tree tick). The v0.3.9
// RT-008 check fires `warning[RT-008]` for any direct
// self-recursion in a `#[deadline]` fn, because unbounded
// recursion can blow the WCET budget. `#[max_depth = N]`
// declares the bound and tells the check to stay silent.
//
// This example: a recursive trajectory-segment accumulator
// that walks `n` segments from the goal back to the start.
// The recursion is structurally bounded by the input
// (`remaining` decreases each call); `#[max_depth = 16]`
// declares that bound for RT-008. Without the attribute the
// build would compile but emit RT-008 noise; with it the
// build is clean.
//
// See docs/v0.3-robotics-guide.md cookbook §3 for the
// pattern; tests/fixtures/t310_rt008_bounded.nr is the
// verify gate fixture; this file shows the same pattern in
// a runnable application example.

// Sum of remaining + (remaining-1) + ... + 1 + 0, computed
// recursively. Mirrors a trajectory accumulator: for each
// remaining segment, add its cost (here: just the index)
// and recurse on the rest. Real planners would query a
// cost function and accumulate weighted; the structure is
// the same.
//
// Bounded by `remaining` decreasing strictly each call. The
// caller passes `remaining <= 16` so #[max_depth = 16] is
// honored. A future v0.4 AST-based RT-008 v2 will tighten
// the check by walking the call graph; v1 takes the author
// at their word via #[max_depth].
#[deadline = 500]
#[no_alloc]
#[no_panic]
#[max_depth = 16]
fn segment_walk(remaining: i64, accumulator: i64) -> i64 {
    if remaining <= 0 { return accumulator; };
    return segment_walk(remaining - 1, accumulator + remaining);
}

fn main() -> i64 {
    print("Bounded-recursion segment walk with #[max_depth = 16]");
    print("segments  total_cost");
    let mut n: i64 = 1;
    while n <= 8 {
        let total: i64 = segment_walk(n, 0);
        let line: str = str_concat(int_to_str(n),
            str_concat("        ", int_to_str(total)));
        print(line);
        n = n + 1;
    };
    return 0;
}
