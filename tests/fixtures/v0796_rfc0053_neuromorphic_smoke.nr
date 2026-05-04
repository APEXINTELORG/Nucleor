// v0.7.96 RFC-0053 Phase A smoke fixture — neuromorphic /
// event-driven type surface. Validates:
//   - Neuron-model tags return stable IDs + name lookup
//   - Spike + SpikeTrain construct, push, count, get, clear
//   - Neuron creation + reset + potential read-back
//   - LIF integrator advances potential + fires on threshold
//   - Synapse + STDP update direction (potentiate / depress)
//   - Rate encode + decode round-trip approximates input rate
//   - MembranePotential Q1.16 round-trip
import "stdlib/rods/neuromorphic.nr"

fn main() -> i64 {
    // Neuron-model tags.
    if neuron_model_lif() != 1 { return 1; };
    if neuron_model_izhikevich() != 2 { return 2; };
    if str_eq(neuron_model_name(1), "LIF") == 0 { return 3; };
    if str_eq(neuron_model_name(99), "Unknown") == 0 { return 4; };

    // Spike + SpikeTrain.
    let s1: Spike = spike(1000, 7);
    if spike_timestamp(s1) != 1000 { return 5; };
    if spike_neuron(s1) != 7 { return 6; };

    let train: SpikeTrain = spike_train_new();
    spike_train_push(train, s1);
    spike_train_push(train, spike(2000, 7));
    spike_train_push(train, spike(3000, 11));
    if spike_train_count(train) != 3 { return 7; };

    let g1: Spike = spike_train_get(train, 1);
    if g1.timestamp_us != 2000 { return 8; };
    if g1.neuron_id != 7 { return 9; };

    let train_cleared: SpikeTrain = spike_train_clear(train);
    if spike_train_count(train_cleared) != 0 { return 10; };

    // Neuron creation + LIF integrator.
    let n: Neuron = neuron_lif_full(50, 20000);
    if neuron_model(n) != neuron_model_lif() { return 11; };

    // Sub-threshold inputs: no fire.
    let f1: i64 = lif_step(n, 1000, 100);
    if f1 != 0 { return 12; };

    // Reset + drive past threshold.
    neuron_reset(n);
    let big: i64 = 50 * 65536 + 1;  // > threshold * Q1.16
    let f2: i64 = lif_step(n, big, 100);
    if f2 != 1 { return 13; };

    // Synapse + STDP.
    let syn0: Synapse = synapse(7, 11, 100, 50);
    if syn0.weight_q1616 != 100 { return 14; };

    let syn_pot: Synapse = stdp_update(syn0, 1000, 1100, 10);
    if syn_pot.weight_q1616 != 110 { return 15; };

    let syn_dep: Synapse = stdp_update(syn0, 1100, 1000, 10);
    if syn_dep.weight_q1616 != 90 { return 16; };

    // Rate encode + decode (roughly, pre-quantization).
    let train2: SpikeTrain = encode_spikes_uniform(100, 1000000, 5);
    if spike_train_count(train2) < 90 { return 17; };
    if spike_train_count(train2) > 110 { return 18; };

    let r: i64 = decode_rate_hz(train2, 5, 1000000);
    if r < 90 { return 19; };
    if r > 110 { return 20; };

    let r_other: i64 = decode_rate_hz(train2, 999, 1000000);
    if r_other != 0 { return 21; };

    // MembranePotential round-trip.
    let mv: MembranePotential = membrane_mv(50);
    if membrane_to_q1616(mv) != 50 * 65536 { return 22; };

    return 0;
}
