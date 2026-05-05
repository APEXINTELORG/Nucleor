# Gap Analyses + RFC Set (2026-05-04)

This directory holds the 14 cornerstone gap-analysis RFCs that
together define the v1.0 launch contract. Each RFC analyzes a
single load-bearing language property, identifies the gap
between the marketing surface and the actual implementation,
and prescribes Phase 1 / 2 / 3 / 4 closure steps.

The gap RFCs were authored by the helper agent on 2026-05-04
and integrated into the build spine on the same day. They are
the canonical truth for what must close before OSS launch.

## Tier ordering

The user's directive (2026-05-04): **memory safety closes first;
the other 13 RFCs are first-class punchlist items after that.**
All Tier A items are launch blockers; Tier B are runtime
launchability; Tier C are stdlib-coherence guarantees.

### Tier A — Load-bearing language properties

1. **[Memory Safety / Borrow / Ownership](Nucleor_Memory_Safety_Borrow_Ownership_Gap_Analysis_and_RFC_2026-05-04.md)** — IN PROGRESS (RFC-0062). Phase 1 closed; Phase 2a Wave A complete; Phase 2b in flight.
2. **[Type System](Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md)** — T-3, T-4 silent fallthrough (char↔int compatibility, empty-type-is-compatible).
3. **[Concurrency](Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md)** — C-1, C-2 cancel token linker bomb + POSIX channel no-op stub. Linux concurrency silently broken.
4. **[Effect / Capability](Nucleor_Effect_Capability_Gap_Analysis_and_RFC_2026-05-04.md)** — E-1 direct `pure fn` side effects now emit `EFF-001`; `requires [...]`, block-form `restricts [...]`, transitive effect rows, and cross-module propagation remain a trust gap.
5. **[Real-Time / Determinism](Nucleor_RealTime_Determinism_Gap_Analysis_and_RFC_2026-05-04.md)** — `#[deadline]` / `#[no_alloc]` enforcement gaps.
6. **[Algebraic Laws](Nucleor_Algebraic_Laws_Gap_Analysis_and_RFC_2026-05-04.md)** — math-and-physics laws not validated by property tests.

### Tier B — Compilation, runtime, execution

7. **[Self-Hosting Bootstrap](Nucleor_Self_Hosting_Bootstrap_Gap_Analysis_and_RFC_2026-05-04.md)** — BOOT-3, BOOT-4: fixed-point check guards a 50-line smoke proxy, NOT the 10K-line compiler self-IR.
8. **[Module / Packaging](Nucleor_Module_Packaging_Gap_Analysis_and_RFC_2026-05-04.md)** — PKG-1 Linux `nuc publish --sign` silently broken; PKG-3 semver constraints don't resolve (only exact strings).
9. **[Interop / FFI](Nucleor_Interop_FFI_Gap_Analysis_and_RFC_2026-05-04.md)** — null contract enforcement; bounds-check trust audits; ABI parity.
10. **[Performance Envelope](Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md)** — PERF-11 `bisect_mem.sh` excursion threshold (600 MB) below current baseline (679 MB), false-positive on every normal run.

### Tier C — Stdlib coherence and correctness

11. **[Numeric Correctness](Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md)** — NUM-G1 f64 literals truncated to 6 decimal digits at lex time. `3.1415926535897932` silently becomes `3.141592`. **Affects every float user.**
12. **[Tensor / ML / Autodiff](Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md)** — ML-1 `nuc_attn_flash` ABI mismatch (rod 6 args, C 7 args). Silent miscompute on every flash-attention call.
13. **[Quantum Subsystem](Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md)** — QM-7 Clifford rod has zero test coverage (41 KB of stabilizer formalism completely unvalidated).
14. **[Robotics Control Stack](Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md)** — ROBO-7 frame-typing safety still Phase A. Mars Climate Orbiter failure mode is live.

## CRITICAL findings (silent miscompute / launch-blocker class)

These are the bubble-up items from across the 14 RFCs that
must close before OSS goes public:

| Code | Doc | Severity | Description |
|---|---|---|---|
| **NUM-G1** | Numeric | LAUNCH-BLOCKER | f64 lex truncation to 6 decimal digits — affects every float user |
| **ML-1** | Tensor/ML | LAUNCH-BLOCKER | nuc_attn_flash ABI mismatch — silent miscompute, tests don't cover |
| **C-1, C-2** | Concurrency | LAUNCH-BLOCKER (Linux) | cancel token + POSIX channel both broken |
| **E-1, E-2, E-3** | Effect/Capability | TRUST | direct pure-fn effects partially closed; requires/restricts/effect rows incomplete |
| **T-3, T-4** | Type System | SILENT-MISCOMPUTE | char↔int compat + empty-type compat fallthrough |
| **BOOT-3, BOOT-4** | Bootstrap | SELF-HOST INTEGRITY | fixed-point check guards 50-line proxy not 10K-line self-IR |
| **PKG-1, PKG-3** | Packaging | LAUNCH-BLOCKER | Linux publish broken; semver doesn't resolve |
| **QM-7** | Quantum | UNVALIDATED | 41KB stabilizer rod has zero test coverage |
| **ROBO-7** | Robotics | SAFETY | frame-typing Phase A only — Mars Climate failure mode live |
| **PERF-11** | Performance | TELEMETRY | bisect_mem threshold below baseline — false-positive every run |

## Sequencing through v1.0

Following the user directive: complete the **memory-safety
RFC (Tier A item 1)** first, then advance the other 13 in
parallel-where-possible, with critical findings prioritized:

1. **Now (in flight):** Memory Safety Phase 2b-3 — close
   the unconditional default-flip ship.
2. **Next batch:** Tier A items 2-6 in parallel where
   independent. The CRITICAL findings (T-3/T-4, E-1/E-2/E-3,
   C-1/C-2) are queued first.
3. **Then:** Tier B items 7-10. BOOT-3/BOOT-4 is the
   self-host correctness gate — high priority.
4. **Then:** Tier C items 11-14. NUM-G1 (float lex
   truncation) goes early because it affects EVERY float
   user. ML-1 (flash-attention ABI) goes early because
   it's pure silent-miscompute on adopter ML code.

The full sequenced punchlist is in
`docs/rfcs/v1_PUNCHLIST.md` (created v0.8.43, updated each ship).

## Ship policy

Each gap-RFC's Phase 1 closures (audits, docs, warning-only
diagnostics) ship FIRST across all RFCs. Then Phase 2a
heuristic warnings. Then Phase 2b proper analysis. Then
Phase 3 default-on. Then Phase 4 hard-error v1.0 cut.

This mirrors the RFC-0062 (memory-safety) sequencing pattern
which has proven stable: Phase 1 docs + Phase 2a heuristic
audit-pass + Phase 2b infrastructure + ... before the actual
default-flip and v1.0 promotion.
