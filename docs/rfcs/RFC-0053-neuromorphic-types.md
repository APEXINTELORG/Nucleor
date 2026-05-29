# RFC-0053 — Neuromorphic Compute Types

**Status:** Draft (frontier — V2.8, language + rod split)
**Date:** 2026-05-03

## Motivation

Neuromorphic / event-driven / spiking-neural-network hardware (Intel Loihi 2, IBM NorthPole, BrainChip Akida, SpiNNaker, Innatera) executes inference at sub-mW / sub-µJ-per-inference levels, IO-bound on event arrival rate not clock cycles. The frontier writeup positions neuromorphic as a peer execution form to CPU/GPU/quantum/photonic — Nucleor's actor / RFC-0035 sendable-actor work is the closest existing surface, but lacks the spike/membrane-potential type primitives needed for SNN-class programs.

This RFC adds the language-level types and the `std.neuro` rod for neuron / synapse / STDP ops.

## Language-level surface

```nucleor
struct Spike { timestamp: u64, neuron_id: u32 }
struct SpikeTrain { spikes: Vec<Spike> }
struct MembranePotential(f64)            // millivolts
struct Synapse { pre: u32, post: u32, weight: f64, delay_us: u16 }

enum NeuronModel { LIF, Izhikevich, AdEx, HodgkinHuxley }

struct Neuron<Model: NeuronModel> {
    state: i64,    // model-dependent state (handle into runtime arena)
}

@neuromorphic[device=loihi2]
fn snn_inference(input: SpikeTrain, network: NetworkHandle) -> SpikeTrain {
    encode_spikes(input);
    route_events(network);
    decode_spikes()
}
```

Key type-system effects:
- Spike vs Tensor are distinct. Adopters can't accidentally pass a tensor to an event-driven path.
- Linear ownership of NetworkHandle: the SNN topology is move-only.
- Effect tag `event_driven`: placed on any fn that consumes spike trains. Composes with capability/effect surface.

## Rod-level surface (`std.neuro`)

- Neuron-model integrators: `lif_step(neuron, current_in, dt) -> Spike?`, `izhikevich_step(...)`, `adex_step(...)`, `hh_step(...)`
- Synapse update: `stdp_update(synapse, pre_spike_time, post_spike_time, learning_rate) -> Synapse`
- `EventRouter` for cross-core spike routing
- `encode_spikes(rate: Vec<f64>, dt_us: u32) -> SpikeTrain` (rate-coded input)
- `decode_spikes(train: SpikeTrain, window_us: u32) -> Vec<f64>` (rate decode)
- `route_events(network: NetworkHandle, schedule: SpikeSchedule)`
- `local_learn(network, rule: LearningRule)` — Hebbian, BCM, Oja, custom

## Implementation

- Parser: types use the existing generic-param machinery; `enum NeuronModel` with model-tag generic param.
- Type-check: Spike / SpikeTrain / MembranePotential are zero-cost wrappers (move-only via existing ownership checker; the wrapper wraps an i64 handle).
- Codegen: ops dispatch to runtime helpers. Today CPU-fallback (Vec<Spike> in DRAM, integrate-and-fire in a tight loop). Hardware backends per device family are future ships.
- Effect: `@neuromorphic` attribute parsed and emitted as fn metadata.

## Cost

V2.8 ship: ~500 LOC compiler (types + placement attribute) + ~1500 LOC stdlib (`std.neuro` rod with CPU-fallback for 4 neuron models, STDP, event router). NO hardware backend.

## Hot-path risk

None. Existing hot paths untouched.

## Frontier connection

Direct frontier writeup §3.2.3 "Neuromorphic event-driven." Closest to existing actor / RFC-0035 sendable concurrency — recommend implementing this BEFORE photonic since the substrate is closer to existing work.

## Closure criteria

- `Spike`, `SpikeTrain`, `MembranePotential` are distinct types (not aliases for primitive scalars).
- `Neuron<LIF>` and `Neuron<Izhikevich>` are distinct types.
- `lif_step` / `izhikevich_step` / `stdp_update` work in CPU fallback.
- A 4-neuron LIF network produces canonical spike pattern under fixture input.
- Round-2 self-host fixed-point holds.
