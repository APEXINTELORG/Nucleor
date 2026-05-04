/* neuromorphic_rt.c — RFC-0053 Phase A: leaky-integrate-and-
 * fire (LIF) neuron runtime. Pure host-CPU implementation;
 * hardware dispatch (Loihi 2 / NorthPole / Akida / SpiNNaker)
 * is the v2.x post-Phase-B ship.
 *
 * State per neuron: { potential_mv (Q1.16), threshold_mv,
 * tau_us, last_t_us }. Integration is exact-exponential per
 * step:
 *   v(t + dt) = v(t) * exp(-dt / tau) + I_in
 * Phase A approximates exp(-dt/tau) with a Q1.16 lookup; full
 * f64 integrator lands in Phase B. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_NEURO_MAX_NEURONS 1024

typedef struct {
    long long potential_q1616;   /* Q1.16 millivolts */
    long long threshold_mv;      /* integer millivolts */
    long long tau_us;
    int in_use;
} NucLIF;

static NucLIF _nuc_neuros[NUC_NEURO_MAX_NEURONS];
static int _nuc_neuro_init = 0;

static void _nuc_neuro_init_table(void) {
    if (_nuc_neuro_init) return;
    for (int i = 0; i < NUC_NEURO_MAX_NEURONS; i++) {
        _nuc_neuros[i].in_use = 0;
    }
    _nuc_neuro_init = 1;
}

long long nuc_neuro_lif_new(long long threshold_mv, long long tau_us) {
    _nuc_neuro_init_table();
    for (int i = 0; i < NUC_NEURO_MAX_NEURONS; i++) {
        if (!_nuc_neuros[i].in_use) {
            _nuc_neuros[i].potential_q1616 = 0;
            _nuc_neuros[i].threshold_mv = threshold_mv;
            _nuc_neuros[i].tau_us = tau_us;
            _nuc_neuros[i].in_use = 1;
            return (long long)i;
        }
    }
    return -1;
}

long long nuc_neuro_lif_reset(long long handle) {
    if (handle < 0 || handle >= NUC_NEURO_MAX_NEURONS) return -1;
    _nuc_neuros[handle].potential_q1616 = 0;
    return 0;
}

long long nuc_neuro_lif_potential_q1616(long long handle) {
    if (handle < 0 || handle >= NUC_NEURO_MAX_NEURONS) return 0;
    return _nuc_neuros[handle].potential_q1616;
}

/* Integrate one step. Returns 1 if the neuron crossed threshold
 * (and resets), 0 otherwise. Phase A uses a simple linear
 * decay approximation: v -= v * dt / tau (Q1.16 arithmetic). */
long long nuc_neuro_lif_step(long long handle, long long current_pa, long long dt_us) {
    if (handle < 0 || handle >= NUC_NEURO_MAX_NEURONS) return 0;
    NucLIF *n = &_nuc_neuros[handle];
    if (!n->in_use) return 0;

    long long v = n->potential_q1616;
    /* Linear decay step (Q1.16): v -= v * dt / tau. */
    if (n->tau_us > 0) {
        long long decay = (v * dt_us) / n->tau_us;
        v -= decay;
    }
    /* Add input current (current_pa scaled to Q1.16 mV).
     * Phase A: 1 pA over 1 us increases potential by 1 Q1.16 unit
     * (this is ABSTRACT — Phase B uses the real C * dV = I * dt
     * relation with capacitance). */
    v += current_pa;

    long long thr_q1616 = n->threshold_mv * 65536LL;
    if (v >= thr_q1616) {
        n->potential_q1616 = 0;   /* Reset post-spike. */
        return 1;
    }
    n->potential_q1616 = v;
    return 0;
}
