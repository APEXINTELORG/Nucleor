// state_machine_rt.c — Finite State Machines for Nucleor
// States, transitions, event-driven dispatch, callbacks.
//
// Compile: clang -c stdlib/runtime/state_machine_rt.c -o target/state_machine_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ================================================================
//  FSM State Machine
// ================================================================

#define FSM_MAX_TRANSITIONS 512
#define FSM_MAX_STATES 64

typedef struct {
    int from_state;
    int event;
    int to_state;
    long long (*action)(long long);
    long long action_arg;
} Transition;

typedef struct {
    int n_states;
    int current;
    Transition transitions[FSM_MAX_TRANSITIONS];
    int n_transitions;
    long long (*on_enter[FSM_MAX_STATES])(long long);
    long long (*on_exit[FSM_MAX_STATES])(long long);
    long long enter_arg[FSM_MAX_STATES];
    long long exit_arg[FSM_MAX_STATES];
    // State names for debugging
    char state_names[FSM_MAX_STATES][32];
    // History
    int history[1024];
    int history_len;
} FSM;

long long nuc_fsm_new(long long n_states) {
    FSM *fsm = (FSM *)calloc(1, sizeof(FSM));
    fsm->n_states = (int)n_states;
    fsm->current = 0;
    return (long long)fsm;
}

void nuc_fsm_set_state_name(long long h, long long state, const char *name) {
    FSM *fsm = (FSM *)(void *)h;
    if (name && (int)state < FSM_MAX_STATES)
        strncpy(fsm->state_names[(int)state], name, 31);
}

void nuc_fsm_set_initial(long long h, long long state) {
    FSM *fsm = (FSM *)(void *)h;
    fsm->current = (int)state;
    fsm->history[0] = (int)state;
    fsm->history_len = 1;
}

void nuc_fsm_add_transition(long long h, long long from, long long event,
                              long long to, long long action_ptr) {
    FSM *fsm = (FSM *)(void *)h;
    if (fsm->n_transitions >= FSM_MAX_TRANSITIONS) return;
    Transition *t = &fsm->transitions[fsm->n_transitions++];
    t->from_state = (int)from;
    t->event = (int)event;
    t->to_state = (int)to;
    t->action = (long long (*)(long long))(void *)action_ptr;
}

void nuc_fsm_on_enter(long long h, long long state, long long fn_ptr) {
    FSM *fsm = (FSM *)(void *)h;
    fsm->on_enter[(int)state] = (long long (*)(long long))(void *)fn_ptr;
}

void nuc_fsm_on_exit(long long h, long long state, long long fn_ptr) {
    FSM *fsm = (FSM *)(void *)h;
    fsm->on_exit[(int)state] = (long long (*)(long long))(void *)fn_ptr;
}

// Fire event, returns new state (or -1 if no matching transition)
long long nuc_fsm_fire(long long h, long long event) {
    FSM *fsm = (FSM *)(void *)h;
    for (int i = 0; i < fsm->n_transitions; i++) {
        Transition *t = &fsm->transitions[i];
        if (t->from_state == fsm->current && t->event == (int)event) {
            // Exit callback
            if (fsm->on_exit[fsm->current])
                fsm->on_exit[fsm->current](fsm->exit_arg[fsm->current]);

            // Transition action
            if (t->action) t->action(t->action_arg);

            // Move to new state
            fsm->current = t->to_state;

            // Record history
            if (fsm->history_len < 1024)
                fsm->history[fsm->history_len++] = fsm->current;

            // Enter callback
            if (fsm->on_enter[fsm->current])
                fsm->on_enter[fsm->current](fsm->enter_arg[fsm->current]);

            return (long long)fsm->current;
        }
    }
    return -1; // no matching transition
}

long long nuc_fsm_current(long long h) {
    return (long long)((FSM *)(void *)h)->current;
}

const char *nuc_fsm_current_name(long long h) {
    FSM *fsm = (FSM *)(void *)h;
    return fsm->state_names[fsm->current];
}

// Check if event is valid from current state
long long nuc_fsm_can_fire(long long h, long long event) {
    FSM *fsm = (FSM *)(void *)h;
    for (int i = 0; i < fsm->n_transitions; i++) {
        if (fsm->transitions[i].from_state == fsm->current &&
            fsm->transitions[i].event == (int)event) return 1;
    }
    return 0;
}

// Get transition history length
long long nuc_fsm_history_len(long long h) {
    return (long long)((FSM *)(void *)h)->history_len;
}

long long nuc_fsm_history_at(long long h, long long idx) {
    FSM *fsm = (FSM *)(void *)h;
    if ((int)idx < 0 || (int)idx >= fsm->history_len) return -1;
    return (long long)fsm->history[(int)idx];
}

void nuc_fsm_free(long long h) { free((void *)h); }
