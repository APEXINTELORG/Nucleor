// v0.8.169 stdlib/rods/state_machine.nr first test coverage.
//
// Finite State Machine — named states, event-driven transitions,
// transition history. Pre-v0.8.169: zero coverage.
//
// Locks four textbook FSM invariants on a 3-state traffic-light
// machine (Red=0, Yellow=1, Green=2) with one event class
// (next=0):
//
//   1. **Initial state** — current() returns the configured initial.
//   2. **Transition fires** — fire(next) at Red transitions to Green
//      (per our wiring); current() reflects new state.
//   3. **can_fire** — true when a transition exists from current
//      state on that event; false otherwise.
//   4. **History tracks transitions** — N fires produce N+1 entries
//      (initial state + N transitions).
//
// on_enter / on_exit fn-pointer callbacks are out-of-scope for
// this smoke (require fn-ptr literal support).
//
// Expected: rc=0.

import "stdlib/rods/state_machine.nr"

fn check_initial_state() -> i64 {
    let m: i64 = fsm_new(3);
    fsm_set_initial(m, 0);
    if fsm_current(m) != 0 { fsm_free(m); return 1; };
    fsm_free(m);
    return 0;
}

fn check_transition_fires() -> i64 {
    let m: i64 = fsm_new(3);
    fsm_set_initial(m, 0);
    // 0 -[next]-> 2 (Red -> Green)
    fsm_add_transition(m, 0, 0, 2, 0);
    // 2 -[next]-> 1 (Green -> Yellow)
    fsm_add_transition(m, 2, 0, 1, 0);
    // 1 -[next]-> 0 (Yellow -> Red)
    fsm_add_transition(m, 1, 0, 0, 0);
    // fsm_fire returns the new state on success, -1 on no transition.
    if fsm_fire(m, 0) != 2 { fsm_free(m); return 2; };
    if fsm_current(m) != 2 { fsm_free(m); return 4; };
    if fsm_fire(m, 0) != 1 { fsm_free(m); return 8; };
    if fsm_current(m) != 1 { fsm_free(m); return 16; };
    if fsm_fire(m, 0) != 0 { fsm_free(m); return 32; };
    if fsm_current(m) != 0 { fsm_free(m); return 64; };
    fsm_free(m);
    return 0;
}

fn check_can_fire() -> i64 {
    let m: i64 = fsm_new(3);
    fsm_set_initial(m, 0);
    fsm_add_transition(m, 0, 0, 1, 0);
    // From state 0 with event 0: can fire = 1
    if fsm_can_fire(m, 0) != 1 { fsm_free(m); return 128; };
    // From state 0 with event 5 (no such transition): can fire = 0
    if fsm_can_fire(m, 5) != 0 { fsm_free(m); return 256; };
    fsm_free(m);
    return 0;
}

fn check_history() -> i64 {
    let m: i64 = fsm_new(3);
    fsm_set_initial(m, 0);
    fsm_add_transition(m, 0, 0, 1, 0);
    fsm_add_transition(m, 1, 0, 2, 0);
    let h0: i64 = fsm_history_len(m);
    fsm_fire(m, 0);
    fsm_fire(m, 0);
    let h2: i64 = fsm_history_len(m);
    if h2 != h0 + 2 { fsm_free(m); return 512; };
    fsm_free(m);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_state();
    fails = fails + check_transition_fires();
    fails = fails + check_can_fire();
    fails = fails + check_history();
    return fails;
}
