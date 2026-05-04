# RFC-0054 — Logical Qubit Type + Pulse-Level Schedules + QIR/OpenQASM Interop

**Status:** Draft (frontier — V2.9, language + rod split)
**Date:** 2026-05-03

## Motivation

Nucleor's `quantum` rod is gate-level (statevector simulator + Clifford + MPS) — strong foundation, but lags the frontier in three dimensions:

1. **No distinction between logical and physical qubits.** Real fault-tolerant quantum requires `LogicalQubit<SurfaceCode, distance=N>` typing, where the type system enforces that an op consumes a logical qubit (with its decoder + correction infrastructure) vs a physical qubit (raw, noisy).

2. **No pulse-level schedules.** Today's gate-level ops are correct but the next frontier (calibration-aware compilation, Pulse on IBM Q, T-count optimization) needs `Pulse`, `Schedule`, `CalibrationData` types.

3. **No QIR / OpenQASM interop.** Adopters can't ingest a QASM circuit from external tooling or emit QIR for cross-platform deployment.

## Language-level surface

```nucleor
enum QECCode { SurfaceCode, ToricCode, ColorCode, SteaneCode, ShorCode }

struct LogicalQubit<Code: QECCode, distance: u8> {
    handle: i64,    // opaque runtime handle backed by physical-qubit array + decoder state
}

struct PhysicalQubit { handle: i64 }

struct Pulse {
    duration_ns: u32,
    amplitude: f64,
    phase: f64,
    waveform: WaveformShape,
}

struct Schedule { pulses: Vec<Pulse>, qubits: Vec<u32> }

struct CalibrationData {
    timestamp: u64,
    backend: str,
    gate_fidelities: HashMap<str, f64>,
    coherence_times_t1_us: Vec<f64>,
    coherence_times_t2_us: Vec<f64>,
    crosstalk: HashMap<(u32, u32), f64>,
}

@within(200ns)              // timing constraint on gate sequence
fn parity_check(q: LogicalQubit<SurfaceCode, 7>) -> i64 { ... }

estimate_resources fn deutsch_jozsa(n: u8) {
    // returns: physical_qubits, depth, T-count, decoder_latency
}
```

Key type-system effects:
- **Logical and physical qubits are distinct types.** Adopters can't accidentally pass a physical qubit to an op that requires a logical one (decoder will be missing).
- **Code + distance as type params:** `LogicalQubit<SurfaceCode, 7>` and `LogicalQubit<SurfaceCode, 9>` are distinct types — affects which decoder lookups are valid.
- **Linear ownership:** all qubit values are move-only (no-cloning theorem at the type level).
- **Timing attribute `@within(N ns)`:** parsed and emitted as schedule metadata.

## Rod-level surface (`std.quantum` extensions)

Existing `quantum` rod gains:
- `prepare_logical(code, distance) -> LogicalQubit<...>`
- `decode_syndrome(q: &LogicalQubit<...>) -> SyndromeData`
- `apply_correction(q: &mut LogicalQubit<...>, syndrome: SyndromeData)`
- `schedule_gate(q, gate, calibration) -> Schedule`
- `estimate_resources(circuit) -> ResourceEstimate { physical_qubits, depth, t_count, decoder_latency_ns }`

## QIR / OpenQASM interop (rod + compiler hook)

- `nuc emit-qir` — emit Microsoft QIR LLVM IR from a `@quantum` fn
- `nuc emit-qasm` — emit OpenQASM 3.0 from a `@quantum` fn
- `qasm_parse(src: str) -> Circuit` — ingest external QASM
- `qir_parse(src: bytes) -> Circuit`

## Implementation

- **Parser:** new types via generic-param machinery. `@within(...)` attribute reuses RFC-0050 quantity-literal infrastructure.
- **Type-check:** Code + distance generic params compared by value at type-equality.
- **Codegen:** logical-qubit ops dispatch to runtime helpers `__nucleor_logical_*`. Today CPU statevector simulator with surface-code distance-3 stub; deeper decoder is future work.
- **QIR emit:** new pass walking the quantum-fn AST and emitting QIR-shaped LLVM IR via the existing inkwell layer.

## Cost

V2.9 ship: ~700 LOC compiler (types + emit pass) + ~1200 LOC stdlib (`std.quantum` extensions, surface-code-distance-3 decoder, QASM parser/emitter, QIR emit). NO hardware backend.

## Hot-path risk

None. Quantum types are orthogonal.

## Frontier connection

Direct frontier writeup §3.2.5. Pairs with **RFC-0048 hardware capability queries** (`target.has(QPU)` gates hardware path).

## Closure criteria

- `LogicalQubit<SurfaceCode, 7>` and `PhysicalQubit` are distinct types.
- `nuc emit-qasm` produces valid OpenQASM 3.0 from a Nucleor quantum fn.
- `nuc emit-qir` produces valid QIR from same source.
- `estimate_resources(deutsch_jozsa(4))` returns coherent physical_qubits / depth / t_count.
- Round-2 self-host fixed-point holds.
