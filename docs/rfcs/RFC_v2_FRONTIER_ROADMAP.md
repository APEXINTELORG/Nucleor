# RFC v2 Frontier Roadmap — physics-aware AI-native heterogeneous-hardware language

> Drafted 2026-05-03 by main agent at end of v0.6.74 → v0.7.13 ship session, after triage of `Desktop/Nucleor_Feature_Diff_and_Frontier_Gap_Report_2026-05-03.md` §3 (frontier gap) and §4 (next-move punch list).
>
> All items are net-new beyond Nucleor V1. Pick items in priority order based on adopter pain × strategic value.

## Priority tiers

### Tier A — Easy wins (run FIRST, before deep V1 work)

These are bounded RFCs (most under 500 LOC compiler-side, plus rod work) that deliver concrete frontier-credibility wins. Each has a complete RFC drafted under `docs/rfcs/RFC-NNNN-*.md`.

#### V2.1 — Coordinate-frame types `Pose<F: Frame>`
**RFC:** `RFC-0046-coordinate-frame-types.md`. Phantom-typed coordinate frame parameter — Mars Climate Orbiter prevention at the type level. Cost: ~200 LOC compiler + ~150 LOC stdlib.

#### V2.2 — Typed dimensional units `unit<T, [kg,m,s,A,K,mol,cd]>`
**RFC:** `RFC-0047-typed-units-7vector.md`. 7-vector SI dimension type with arithmetic that adds/subtracts dim vectors. Lifts V2's existing implementation. Cost: ~400 LOC compiler + ~200 LOC stdlib.

#### V2.3 — Hardware capability queries `target.has(FP4)`
**RFC:** `RFC-0048-hardware-capability-queries.md`. Compile-time-resolved `if target.has(X)` with DCE-elided dead branches. Cost: ~300 LOC.

#### V2.4 — Memory-space type tags `Tensor<f32, HBM>`
**RFC:** `RFC-0049-memory-space-type-tags.md`. Phantom memory-space param prevents cross-pool ops. Cost: ~200 LOC + stdlib.

#### V2.5 — Energy / thermal budget attributes
**RFC:** `RFC-0050-energy-thermal-attributes.md`. `@energy(max=2mJ)` / `@thermal(max_temp=70C)` parsed and emitted as metadata; estimator deferred. Cost: ~150 LOC.

#### V2.6 — Foundation-model provenance type `Model<...>`
**RFC:** `RFC-0051-model-provenance-type.md`. Typed wrapper carrying weights_hash + dataset_lineage + license + safety_eval + quantization through the API. Cost: ~400 LOC compiler + ~300 LOC stdlib.

### Tier B — Medium frontier (each = standalone execution form)

#### V2.7 — Photonic compute types
**RFC:** `RFC-0052-photonic-types.md`. Language: OpticalTensor / ComplexAmplitude / Phase / Wavelength / MZIMesh + `@photonic` placement. Rod: `std.photonic`. Cost: ~600 LOC compiler + ~800 LOC stdlib (CPU fallback only — hardware backend is per-vendor future ship).

#### V2.8 — Neuromorphic compute types
**RFC:** `RFC-0053-neuromorphic-types.md`. Language: Spike / SpikeTrain / MembranePotential / Synapse + `@neuromorphic` placement. Rod: `std.neuro` (LIF / Izhikevich / AdEx / Hodgkin-Huxley + STDP + EventRouter). Cost: ~500 LOC compiler + ~1500 LOC stdlib. **Recommended FIRST execution form to lead with** — closest to existing actor / RFC-0035 sendable concurrency.

#### V2.9 — Logical qubit type + pulse schedules + QIR/OpenQASM interop
**RFC:** `RFC-0054-logical-qubit-type.md`. Language: `LogicalQubit<SurfaceCode, distance=N>` + `@within(...)` timing + `estimate_resources` block. Rod: `std.quantum` extensions + QASM/QIR parser+emitter. Cost: ~700 LOC compiler + ~1200 LOC stdlib.

### Tier C — Large frontier directions (multi-week each)

#### V2.10 — `std.distributed` collectives + topology-aware sharding
**RFC:** `RFC-0055-distributed-collectives.md`. Language: `ShardedTensor` + `ShardSpec`. Rod: 8 collectives + 3 parallel patterns + RDMA + checkpoint/restart. CPU MPI fallback first; NCCL/RCCL per vendor later. Cost: ~400 LOC compiler + ~3000 LOC stdlib.

#### V2.11 — Deterministic replay across accelerators
**RFC:** `RFC-0056-deterministic-replay.md`. Language: `replay { ... } { ... }` block. Rod: `std.replay` + `@replay-instrumented` annotations on rand/tensor/io/actuator/model. Cost: ~400 LOC compiler + ~600 LOC stdlib + ~200 LOC instrumentation.

#### V2.12 — Enclave types + info-flow labels
**RFC:** `RFC-0057-enclave-types.md`. Language: `Secret<T>` / `Public<T>` / `Confidential<T>` + `@enclave(<engine>)` + `@attested`. Rod: `std.security` extensions. Cost: ~600 LOC compiler + ~800 LOC stdlib (no hardware backend yet).

#### V2.13 — Post-quantum crypto in `std.security`
**RFC:** `RFC-0058-pq-crypto-stdlib.md`. ML-KEM + ML-DSA + SLH-DSA via liboqs. Dual-sign Nucleor releases (Ed25519 + ML-DSA) going forward. Cost: ~2000 LOC stdlib + 50 LOC compiler attribute.

### Tier D — Future / strategic (V3.x, deferred)

#### V3.x — Multi-Level IR (5-stage MLIR-style)
**SKETCH:** `RFC-0059-multi-level-IR-sketch.md`. Intent → Algorithm → Schedule → Device → Machine. Pending user commit to a 6-month v3.0 cycle. Do not implement until ≥3 V2 RFCs are blocked on IR-modeling friction OR MLIR-ecosystem interop becomes a strategic priority.

## Cost summary

| Tier | RFCs | Total compiler LOC | Total stdlib LOC | Perf risk |
|---|---|---|---|---|
| A (easy wins) | RFC-0046–RFC-0051 | ~1650 | ~650 | Low (mostly phantom types) |
| B (medium frontier) | RFC-0052–RFC-0054 | ~1800 | ~3500 | Low |
| C (large frontier) | RFC-0055–RFC-0058 | ~3450 | ~6400 | Low–medium |
| D (V3.x sketch) | RFC-0059 | TBD (~10k+ refactor) | — | High |

**Tier A grand total:** ~2300 LOC. Should run as a queue ahead of any deep V1 work.

## What's NOT in this roadmap

Per `Desktop/Nucleor_Drift_Triage_2026-05-03.md`:
- **Drift-restoration items (V1.12 / V1.13 / V1.14)** are in `RFC_v1_FORWARD_ROADMAP.md` Tier 4. Run alongside Tier-A frontier easy wins.
- **Governance attributes (V1.15)** — pending user articulation. Placeholder at `SPEC-governance-attributes.md`.
- **LSP (V1.16)** — application, not language. Spec at `SPEC-LSP-server.md`.

## Rod-vs-language matrix (frontier additions)

| Item | Language-level (types/effects/syntax) | Rod-level (algorithms/runtime) | Application (separate tool) |
|---|---|---|---|
| Coordinate frames | ✅ Pose<F> phantom-typed | extend `tf` / `kinematics` rods | — |
| Typed units | ✅ unit<T, dim> 7-vector | extend `units` / `physics` rods | — |
| HW capability queries | ✅ target.has(X) builtin | — | — |
| Memory-space tags | ✅ Tensor<T, Space> | extend `mem` / `tensor_nd` rods | — |
| Energy/thermal attrs | ✅ `@energy` / `@thermal` | — | — |
| Model provenance | ✅ Model<Arch, ...> | new `model` rod | — |
| Photonic | ✅ types + `@photonic` | new `std.photonic` rod | — |
| Neuromorphic | ✅ types + `@neuromorphic` | new `std.neuro` rod | — |
| Logical qubits | ✅ types + `@within` | extend `quantum` rod | `nuc emit-qasm` / `nuc emit-qir` |
| Distributed | ✅ ShardedTensor type | new `std.distributed` rod | `nuc run --np=N` MPI launcher |
| Replay | ✅ replay { } block | new `std.replay` rod | — |
| Enclave + info-flow | ✅ Secret/Public/Confidential + `@enclave` | extend `std.security` | — |
| PQ crypto | crypto-agility annotation only | extend `std.security` | dual-sign release pipeline |
| Multi-level IR | ✅ entire IR refactor | — | — |
| LSP server | (compiler `--lsp-mode` flag) | — | ✅ separate `nucleor-lsp` daemon |
| Governance attrs | ✅ `@authored` / `@policy` | — | `nuc certify` / `nuc evidence` CLI |

## See also

- `RFC_v1_FORWARD_ROADMAP.md` — V1.1 through V1.16 (in-progress / drift-restore / pending-articulation).
- `Desktop/Nucleor_Drift_Triage_2026-05-03.md` — verified-drift triage memo.
- `Desktop/Nucleor_Build_Spine/BUILD_PATH_v0.4_to_v1.3.md` — canonical 1–13 punchlist.
- `Desktop/Nucleor_Feature_Diff_and_Frontier_Gap_Report_2026-05-03.md` — source feature-diff report (post-NS_Sage scrub).
- `Desktop/Nucleor_Translate/` — language translator project.
- `Desktop/Nucleor_Build_Spine/03_TRIAGE/ML_EXPANSION_SET_INTEGRATION_2026-05-01.md` — ML expansion brief.
- `Desktop/Nucleor_Build_Spine/07_CODEX_DOCS/ML_EXPANSION_INPUTS_2026-05-01/` — ML expansion implementation plan + API surface index + kernel/backend/runtime spec.
- `Desktop/Nucleor_ML_Expansion_Spine_Integration_Brief_2026-05-01.md` — top-level ML brief.
