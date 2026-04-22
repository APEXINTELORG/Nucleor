// =====================================================
// rods/state_machine — Finite State Machines
// =====================================================
// Import: import "stdlib/rods/state_machine.nr"
// Provides: state-machine construction, named states, event-driven
//   transitions with on-enter / on-exit hooks, current-state and
//   history queries.
// =====================================================

#cfile "../runtime/state_machine_rt.c"

extern fn nuc_fsm_new(n_states: i64) -> i64;
extern fn nuc_fsm_set_state_name(h: i64, state: i64, name: str);
extern fn nuc_fsm_set_initial(h: i64, state: i64);
extern fn nuc_fsm_add_transition(h: i64, from: i64, event: i64, to: i64, action: i64);
extern fn nuc_fsm_on_enter(h: i64, state: i64, fn_ptr: i64);
extern fn nuc_fsm_on_exit(h: i64, state: i64, fn_ptr: i64);
extern fn nuc_fsm_fire(h: i64, event: i64) -> i64;
extern fn nuc_fsm_current(h: i64) -> i64;
extern fn nuc_fsm_can_fire(h: i64, event: i64) -> i64;
extern fn nuc_fsm_history_len(h: i64) -> i64;
extern fn nuc_fsm_history_at(h: i64, idx: i64) -> i64;
extern fn nuc_fsm_free(h: i64);

fn fsm_new(n_states: i64) -> i64 { return nuc_fsm_new(n_states); }
fn fsm_set_name(h: i64, state: i64, name: str) { nuc_fsm_set_state_name(h, state, name); }
fn fsm_set_initial(h: i64, state: i64) { nuc_fsm_set_initial(h, state); }
fn fsm_add_transition(h: i64, from: i64, event: i64, to: i64, action: i64) {
    nuc_fsm_add_transition(h, from, event, to, action);
}
fn fsm_on_enter(h: i64, state: i64, fn_ptr: i64) { nuc_fsm_on_enter(h, state, fn_ptr); }
fn fsm_on_exit(h: i64, state: i64, fn_ptr: i64) { nuc_fsm_on_exit(h, state, fn_ptr); }
fn fsm_fire(h: i64, event: i64) -> i64 { return nuc_fsm_fire(h, event); }
fn fsm_current(h: i64) -> i64 { return nuc_fsm_current(h); }
fn fsm_can_fire(h: i64, event: i64) -> i64 { return nuc_fsm_can_fire(h, event); }
fn fsm_history_len(h: i64) -> i64 { return nuc_fsm_history_len(h); }
fn fsm_history_at(h: i64, idx: i64) -> i64 { return nuc_fsm_history_at(h, idx); }
fn fsm_free(h: i64) { nuc_fsm_free(h); }
