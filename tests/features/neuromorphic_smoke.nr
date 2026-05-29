// v0.8.220 stdlib/rods/neuromorphic.nr first test coverage.
//
// RFC-0053 Phase A: neuromorphic / event-driven type surface
// (rod-only). Pre-v0.8.220: zero coverage on the standalone
// rod. Phase B (~600 LOC compiler + ~800 LOC stdlib + Loihi 2 /
// NorthPole / Akida / SpiNNaker backend dispatch) is deferred.
//
// Locks four invariants Phase B compiler enforcement must NOT
// regress:
//
//   1. Stable neuron-model IDs — LIF=1, Izhikevich=2,
//      AdEx=3, HodgkinHuxley=4 (the wire format adopter code
//      depends on).
//   2. Spike construction round-trip — spike(1234, 7) →
//      timestamp 1234, neuron 7.
//   3. SpikeTrain push tracks count — 3 pushes → count=3,
//      get(0) and get(2) round-trip.
//   4. LIF reset → 0 potential — newly reset LIF state
//      reads zero membrane potential.
//
// Expected: rc=0.

import "stdlib/rods/neuromorphic.nr"

fn check_model_ids() -> i64 {
    if neuron_model_lif() != 1 { return 1; };
    if neuron_model_izhikevich() != 2 { return 2; };
    if neuron_model_adex() != 3 { return 4; };
    if neuron_model_hodgkin_huxley() != 4 { return 8; };
    return 0;
}

fn check_spike_round_trip() -> i64 {
    let s: Spike = spike(1234, 7);
    if spike_timestamp(s) != 1234 { return 16; };
    if spike_neuron(s) != 7 { return 32; };
    return 0;
}

fn check_train_push_count() -> i64 {
    let t: SpikeTrain = spike_train_new();
    spike_train_push(t, spike(100, 0));
    spike_train_push(t, spike(200, 1));
    spike_train_push(t, spike(300, 2));
    if spike_train_count(t) != 3 { return 64; };
    let s0: Spike = spike_train_get(t, 0);
    if spike_timestamp(s0) != 100 { return 128; };
    if spike_neuron(s0) != 0 { return 256; };
    let s2: Spike = spike_train_get(t, 2);
    if spike_timestamp(s2) != 300 { return 512; };
    if spike_neuron(s2) != 2 { return 1024; };
    return 0;
}

fn check_lif_reset_zero() -> i64 {
    let h: i64 = nuc_neuro_lif_new(f64_to_bits(0.0 - 50.0), 1000);
    nuc_neuro_lif_reset(h);
    let p: i64 = nuc_neuro_lif_potential_q1616(h);
    if p != 0 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_model_ids();
    fails = fails + check_spike_round_trip();
    fails = fails + check_train_push_count();
    fails = fails + check_lif_reset_zero();
    return fails;
}
