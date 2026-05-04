# RFC-0056 — Deterministic Replay Across Accelerators

**Status:** Draft (frontier — V2.11, language + rod split)
**Date:** 2026-05-03

## Motivation

Reproducibility is the hardest problem in heterogeneous-hardware ML/RL/control: same code on the same data can produce different results across:
- non-deterministic GPU kernel scheduling (atomics, reduction order)
- floating-point fused-multiply-add availability variation
- RNG seed propagation gaps
- async timing jitter
- model-version drift between training and serving
- sensor-timestamp non-monotonic skew

The frontier writeup proposes deterministic replay as a first-class language form: a `replay { ... }` block captures all sources of non-determinism (rng_seed, kernel_versions, model_hash, device_manifest, sensor_timestamps, actuator_commands) into a replay-log, and re-running against that log produces byte-identical output.

## Design

### Language-level: `replay { ... }` block

```nucleor
replay {
    rng_seed: 42,
    deterministic: true,
    kernel_version: "tensor_v2.1",
    log_path: "/tmp/run.replay",
} {
    let result = inference_pipeline(model, input);
    actuator_commands.send(result);
}
```

Inside the block:
- All `rand()` calls draw from a deterministic PRNG seeded by `rng_seed`.
- All GPU ops set the deterministic-mode flag (LIBRARY-DEPENDENT — cuDNN supports it; many vendor kernels don't).
- All sensor reads + actuator commands are timestamp-stamped and logged to `log_path`.
- Model load asserts `model.hash == declared_hash`; mismatch panics.

Re-running the same code with `replay { source_path: "/tmp/run.replay", ... }` reads from the log instead of producing fresh non-determinism, and asserts byte-identical output at every checkpoint.

### Rod-level: `std.replay`

- `replay_log_open(path: str, mode: ReplayMode) -> ReplayHandle`
- `replay_log_event(handle, event: ReplayEvent)`
- `replay_log_close(handle)`
- `replay_assert_byte_identical(handle, current: bytes, declared: bytes) -> Result<(), ReplayMismatch>`

ReplayEvent variants: `RngDraw`, `KernelLaunch`, `SensorRead`, `ActuatorWrite`, `ModelLoad`, `Checkpoint`.

## Implementation

V2.11 ship:
- **Parser:** `replay { ... } { ... }` block syntax. Outer braces hold key-value config; inner braces hold the body.
- **Lower:** the block synthesizes:
  - PRNG init at block entry from declared seed
  - Replay-log-open at block entry
  - Replay-log-close at block exit (or panic-unwind)
  - Per-op event logging (only ops marked `@replay-instrumented` in the autodiff/quantum/distributed/io rods)
- **Stdlib:** `std.replay` rod with handle + event types + assertion machinery.
- **Existing rods:** add `@replay-instrumented` annotation to `rand`, `tensor` ops, `io::read_sensor`, `actuator::send`, `model::load`. ~30 op sites.

## Cost

V2.11 ship: ~400 LOC compiler (block parser + lowering pass) + ~600 LOC stdlib + ~200 LOC instrumentation across existing rods. NO vendor-kernel deterministic-mode wiring (out of scope — adopters set their own flags via `target.feature(...)` per RFC-0048).

## Hot-path risk

Low. Replay instrumentation only activates inside a `replay { ... }` block — non-replay code paths get the existing fast path.

## Frontier connection

Direct frontier writeup §3.2.6 "Deterministic-replay runtime across accelerators." Pairs with **RFC-0051 Model<...> provenance** (replay asserts model hash matches declared); pairs with **RFC-0055 distributed collectives** (replay logs the per-rank seeds + collective ordering).

## Closure criteria

- `replay { rng_seed: 42 } { let r = rand(); ... }` produces deterministic `r` regardless of host clock.
- Re-running against a recorded log byte-equals the original output at every checkpoint.
- Model-hash mismatch panics with clean diag.
- Round-2 self-host fixed-point holds.
