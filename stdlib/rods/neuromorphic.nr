// rods/neuromorphic — RFC-0053 Phase A: neuromorphic /
// event-driven type surface (rod-only, no compiler change).
//
// The full RFC-0053 ship adds language-level types
// `Spike` / `SpikeTrain` / `Neuron<Model>` + placement attribute
// `@neuromorphic` plus hardware dispatch (~600 LOC compiler +
// ~800 LOC stdlib). Phase A (this rod) lands the canonical type
// surface + neuron-model tags + a leaky-integrate-and-fire
// integrator that runs on host CPU for adopters who want event-
// driven semantics today.
//
// Sister to RFC-0052 photonic Phase A (v0.7.95). Both are V2
// frontier Tier-B follow-ons after the Tier-A close-out at
// v0.7.90. Hardware dispatch (Loihi 2, NorthPole, Akida,
// SpiNNaker) is the v2.x post-Phase-B ship.
//
// Workflow today:
//
//   import "stdlib/rods/neuromorphic.nr"
//
//   let n: Neuron = neuron_lif(neuron_model_lif());
//   let s: Spike = spike(1234, 7);  // (timestamp_us, neuron_id)
//   let train: SpikeTrain = spike_train_new();
//   spike_train_push(train, s);
//   let post: Spike = lif_step(n, 100, 100);  // (current_pa, dt_us)

#cfile "../runtime/neuromorphic_rt.c"

extern fn nuc_neuro_lif_step(state_handle: i64, current_pa: i64, dt_us: i64) -> i64;
extern fn nuc_neuro_lif_new(threshold_mv: i64, tau_us: i64) -> i64;
extern fn nuc_neuro_lif_reset(state_handle: i64) -> i64;
extern fn nuc_neuro_lif_potential_q1616(state_handle: i64) -> i64;

// =====================================================
// Neuron-model tags (stable IDs).
// =====================================================
fn neuron_model_lif()           -> i64 { return 1; }   // leaky integrate-and-fire
fn neuron_model_izhikevich()    -> i64 { return 2; }
fn neuron_model_adex()          -> i64 { return 3; }   // adaptive-exponential
fn neuron_model_hodgkin_huxley() -> i64 { return 4; }
fn neuron_model_unknown()       -> i64 { return 0; }

fn neuron_model_name(id: i64) -> str {
    if id == 1 { return "LIF"; };
    if id == 2 { return "Izhikevich"; };
    if id == 3 { return "AdEx"; };
    if id == 4 { return "HodgkinHuxley"; };
    return "Unknown";
}

// =====================================================
// Spike + SpikeTrain types.
// timestamp_us: microsecond-resolution spike time.
// neuron_id:    the neuron that fired the spike.
// SpikeTrain:   ordered Vec of spikes; adopters push in
//               time order, decoders walk in order.
// =====================================================
struct Spike {
    timestamp_us: i64,
    neuron_id: i64,
}

struct SpikeTrain {
    spikes: Vec<i64>,   // packed: timestamps and ids interleaved
}

fn spike(timestamp_us: i64, neuron_id: i64) -> Spike {
    return Spike { timestamp_us: timestamp_us, neuron_id: neuron_id };
}

fn spike_timestamp(s: Spike) -> i64 { return s.timestamp_us; }
fn spike_neuron(s: Spike) -> i64 { return s.neuron_id; }

fn spike_train_new() -> SpikeTrain {
    let v: Vec<i64> = Vec::new();
    return SpikeTrain { spikes: v };
}

fn spike_train_push(t: SpikeTrain, s: Spike) -> i64 {
    t.spikes.push(s.timestamp_us);
    t.spikes.push(s.neuron_id);
    return 0;
}

fn spike_train_count(t: SpikeTrain) -> i64 {
    return vec_len(t.spikes) / 2;
}

fn spike_train_get(t: SpikeTrain, idx: i64) -> Spike {
    let base: i64 = idx * 2;
    let ts: i64 = vec_get(t.spikes, base);
    let id: i64 = vec_get(t.spikes, base + 1);
    return Spike { timestamp_us: ts, neuron_id: id };
}

fn spike_train_clear(t: SpikeTrain) -> SpikeTrain {
    // Phase A: returns a fresh empty SpikeTrain. Adopters
    // re-bind via `let train = spike_train_clear(train);`.
    let v: Vec<i64> = Vec::new();
    return SpikeTrain { spikes: v };
}

// =====================================================
// MembranePotential (Q1.16 millivolts) + Synapse type.
// =====================================================
struct MembranePotential {
    millivolts_q1616: i64,
}

fn membrane_mv(int_part: i64) -> MembranePotential {
    return MembranePotential { millivolts_q1616: int_part * 65536 };
}

fn membrane_to_q1616(m: MembranePotential) -> i64 { return m.millivolts_q1616; }

struct Synapse {
    pre: i64,
    post: i64,
    weight_q1616: i64,
    delay_us: i64,
}

fn synapse(pre: i64, post: i64, weight_q1616: i64, delay_us: i64) -> Synapse {
    return Synapse { pre: pre, post: post, weight_q1616: weight_q1616, delay_us: delay_us };
}

// STDP (spike-timing-dependent plasticity) update — Phase A
// uses a simple symmetric exponential window in Q1.16. Phase B
// promotes to per-device hardware dispatch.
fn stdp_update(s: Synapse, pre_t: i64, post_t: i64, lr_q1616: i64) -> Synapse {
    let dt: i64 = post_t - pre_t;
    let mut delta: i64 = 0;
    if dt > 0 {
        // Pre-before-post: potentiate.
        delta = lr_q1616;
    };
    if dt < 0 {
        // Post-before-pre: depress.
        delta = 0 - lr_q1616;
    };
    let new_w: i64 = s.weight_q1616 + delta;
    return Synapse { pre: s.pre, post: s.post, weight_q1616: new_w, delay_us: s.delay_us };
}

// =====================================================
// Neuron type — wraps the runtime LIF state handle.
// =====================================================
struct Neuron {
    model: i64,
    state: i64,
}

fn neuron_lif() -> Neuron {
    // Defaults: threshold = 50 mV, tau = 20 ms (20000 us).
    let h: i64 = nuc_neuro_lif_new(50, 20000);
    return Neuron { model: neuron_model_lif(), state: h };
}

fn neuron_lif_full(threshold_mv: i64, tau_us: i64) -> Neuron {
    let h: i64 = nuc_neuro_lif_new(threshold_mv, tau_us);
    return Neuron { model: neuron_model_lif(), state: h };
}

fn neuron_model(n: Neuron) -> i64 { return n.model; }

fn neuron_potential(n: Neuron) -> MembranePotential {
    let q: i64 = nuc_neuro_lif_potential_q1616(n.state);
    return MembranePotential { millivolts_q1616: q };
}

fn neuron_reset(n: Neuron) -> i64 {
    return nuc_neuro_lif_reset(n.state);
}

// =====================================================
// LIF integrator — single-step. Returns the post-step
// firing flag (1 if spiked, 0 otherwise).
// =====================================================
fn lif_step(n: Neuron, current_pa: i64, dt_us: i64) -> i64 {
    return nuc_neuro_lif_step(n.state, current_pa, dt_us);
}

// =====================================================
// Rate encoding / decoding helpers (Phase A — pure
// Nucleor; Phase B promotes to hardware-accelerated path).
// =====================================================
fn encode_spikes_uniform(rate_hz: i64, duration_us: i64, neuron_id: i64) -> SpikeTrain {
    let train: SpikeTrain = spike_train_new();
    if rate_hz <= 0 { return train; };
    let period_us: i64 = 1000000 / rate_hz;
    if period_us <= 0 { return train; };
    let mut t: i64 = 0;
    while t < duration_us {
        let s: Spike = spike(t, neuron_id);
        spike_train_push(train, s);
        t = t + period_us;
    };
    return train;
}

fn decode_rate_hz(train: SpikeTrain, neuron_id: i64, window_us: i64) -> i64 {
    if window_us <= 0 { return 0; };
    let n: i64 = spike_train_count(train);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let s: Spike = spike_train_get(train, i);
        if s.neuron_id == neuron_id { count = count + 1; };
        i = i + 1;
    };
    // hz = count * (1_000_000 / window_us)
    return (count * 1000000) / window_us;
}
