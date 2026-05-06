# Nucleor — Quantum Subsystem Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The quantum domain pillar

Quantum is positioned as a domain stdlib (not a hardware-targeting compiler). Four simulators (statevector, MPS, Clifford stabilizer, differentiable multi-core) cover ~12 to ~32 qubits depending on technique. S12b trace protocol provides provenance. RFC-0054 deferred QIR/OpenQASM/pulse hardware interop to Phase B.

**Headline finding: Clifford rod coverage is partially closed, not complete.** 41 KB runtime with stabilizer formalism, distance computation, and error detection now has deterministic smoke coverage, but rotated surface-code d=3 and published weight-enumerator parity remain open.

**Second finding: dual entanglement trackers exist and are not wired together.** `quantum_rt.c` has trace-only UF; `qsim_graph_rt.c` has queryable UF. Caller using qsim_graph must manually register entanglements separately from running circuits — easy to forget, no enforcement.

---

# Part II — Gap Inventory

## QM-1 — Header advertises functions that don't exist — **LOW**
`qsim_copy`, `qsim_statevec`, `qsim_prob` advertised in `quantum.nr` header but not implemented in body. Doc/spec drift.

## QM-2 — Statevector MAX_QUBITS 32 silently miscounts at >32 qubits — **MEDIUM**
Static array in entanglement tracker. Tracker silently stops counting for q >= 32; simulator operates on more qubits — silent miscount in trace events for circuits with 33+ qubits.

## QM-3 — MPS rod exposes only raw integer gate_type enum — **MEDIUM**
No named gate functions (`mps_h`, `mps_x`, `mps_cnot`). Enum values 0–7 documented only in C source comment. Ergonomic gap.

## QM-4 — MPS non-adjacent CNOT routing introduces untracked SWAP overhead — **MEDIUM**
SWAP count not reported back to Nucleor or trace. `qtrace_set_original` would double-count SWAP overhead as "transpiler overhead."

## QM-5 — MPS SVD: 100-iter Jacobi with silent clamp on negative eigenvalues — **HIGH**
Correct for small bond dimensions but no documented convergence guarantee beyond 1e-28 off-norm. Near max bond (64), SVD may not converge; singular values silently clamped to zero via `max(eigenvalue, 0)` — **potential silent truncation error with no warning.**

## QM-6 — MPS smoke test is allocation-only — **HIGH**
`mps_smoke.nr` tests only `mps_init` + free. **No gate applied, no statevector extracted, no correctness verified.** Bell-state test through MPS path does not exist.

## QM-7 — Clifford rod coverage partially closed — **CRITICAL REMAINING**
41 KB runtime with stabilizer formalism, distance, error detection. The original zero-test gap is now partially closed by deterministic Bell/GHZ, gate identity, reset/rebuild, and known [[5,1,3]] distance/detectable-error smokes. Remaining launch risk is validation breadth: rotated surface-code d=3 and published weight-enumerator parity are still open, and the suite is not a randomized stabilizer property test.

## QM-8 — Two entanglement trackers not wired together — **HIGH**
`quantum_rt.c` (32-qubit, trace-only, no active flag) and `qsim_graph_rt.c` (1024-qubit, queryable, union-by-size). When `qsim_cnot` fires, calls `rods_trace_entangle` (trace UF) but NOT `nuc_qsim_entangle_register` (queryable UF). Caller using `qsim_graph.nr` must manually register entanglements separately — easy to forget, no enforcement.

## QM-9 — Gate-influence DAG silent overflow at 4096 gates — **MEDIUM**
`NUC_QSIM_MAX_GATES 4096`. Larger circuits return -1 from `nuc_qsim_gate_record` but **nothing signals this to Nucleor layer** — silent overflow with partial DAG data.

## QM-10 — CUDA simulator has only H/X/Z/CNOT — **HIGH**
No Ry/Rz/T/S/CCX/CZ/SWAP. Insufficient for VQE/QAOA. CPU fallback documented in comments but not implemented. No Nucleor rod wrapper — GPU path inaccessible from Nucleor circuits without raw extern bindings.

## QM-11 — diff_sim capped at 12 qubits, hard-coded constant — **MEDIUM**
ADAPT-VQE and QEC RL experiments used up to 13 qubits. **13+ qubits cannot use diff_sim.** Compile-time constant in C, not runtime check with clear error.

## QM-12 — diff_sim and MPS share gate type enum but neither exposes constants — **LOW**
Both start H=0/CNOT=1/X=2 but enum not in shared header or Nucleor constant. Magic integers at callsites. Adding new gate to one without other silently diverges.

## QM-13 — Pulse-level schedule has no qubit-parallel constraint enforcement — **MEDIUM**
`Schedule` doesn't enforce qubit-parallel constraints: two pulses on same qubit at overlapping times can be pushed without error. `schedule_push` places pulses sequentially on global timeline, ignoring qubit_id.

## QM-14 — Logical qubit registry no partial release — **LOW**
Process-global static array `_nuc_lqs[256]`. No free/remove operation, only `nuc_lq_clear` wipes everything. `nuc_lq_register` returns -1 on overflow with no Nucleor-level check in `logical_qubit_new`.

## QM-15 — QIR and OpenQASM completely absent — **HIGH** (deferred per RFC-0054 Phase B)
No emit, no ingest, no stub. Users wanting to port from Qiskit/Cirq or run on IBM Q have no path from Nucleor.

## QM-16 — No Kraus-operator or density-matrix noise model — **MEDIUM**
diff_sim noise is learnable parameterized depolarizing but not independently specifiable. Cannot set "apply dephasing channel after each T gate with rate 0.01." Trace-close noise estimate is heuristic, not simulation result.

## QM-17 — Quantum-classical mid-circuit feedback by convention only — **LOW**
`qsim_measure` returns i64; caller branches. No `qsim_if_measure` primitive. This distinction matters for hardware-targeting tools (RFC-0054 Phase B).

## Cross-cutting risks
- **Correctness validation thin.** Only executed correctness test for statevector is Bell entanglement (QM-6). No assertion that |H|0⟩|² = 0.5 within tolerance, no GHZ, no phase-sensitive (T/S/Rz angles). Clifford now has deterministic smoke coverage for Bell/GHZ, gate identity, reset/rebuild, and known [[5,1,3]] distance/error-detection behavior, but no broad randomized stabilizer property suite and no rotated surface-code d=3 / published enumerator parity.
- **Static-capacity constants scattered across four runtimes** (32, 20, 64, 12, 1024, 4096) not centralized, not surfaced to Nucleor as named constants, some overflow silently.
- **Dual-tracker fragmentation risk** (QM-8) — architecturally fine for Phase A but if RFC-0061 Tier 3 Phase B wires them together, both will need active-flag discrepancy review.
- **MPS Jacobi SVD numerical stability** (QM-5) — clamp on negative residuals masks numerical noise as zero bond dimension.

---

# Part III — RFC

## 3.1. Goals
1. Finish the QM-7 validation gap: keep the landed deterministic Clifford smokes and add rotated surface-code d=3 plus published weight-enumerator parity.
2. Wire the two entanglement trackers together (QM-8).
3. Add named gate APIs and centralized capacity constants.
4. Document the Clifford and MPS limits prominently.

## 3.2. Closure plan

**Phase 1 (emergency, test coverage):**
- QM-7: deterministic Clifford suite now covers Bell state via H + CNOT, 3-qubit GHZ, gate identities, reset/rebuild, and known [[5,1,3]] distance/detectable-error behavior. Remaining Phase 2 closure is a rotated surface-code d=3 fixture plus published weight-enumerator parity. **No Clifford code ships without these tests.**
- QM-6: extend `mps_smoke.nr` to actually apply gates, extract statevector, verify Bell-state probabilities to 1e-10 tolerance.
- QM-1: remove unimplemented function names from `quantum.nr` header comment.
- QM-2: emit warning at runtime when statevector exceeds tracker capacity (32 qubits). Document as known limit.

**Phase 2 (short-term):**
- QM-3: add named gate wrappers in `mps.nr` (`mps_h`, `mps_x`, `mps_cnot`, etc.). Hide raw integer enum.
- QM-8: wire `qsim_cnot` to call BOTH `rods_trace_entangle` AND `nuc_qsim_entangle_register`. Single source of truth for entanglement state.
- QM-9: emit runtime panic when gate DAG exceeds 4096 gates instead of silent -1.
- QM-11: make `DS_MAX_QUBITS` runtime-configurable or at least raise to 16. Surface clear error to Nucleor layer on overflow.
- QM-12: define gate type enum in `quantum.nr` as Nucleor constants. Both diff_sim and MPS reference the same constants.
- QM-13: enforce qubit-parallel constraints in `schedule_push`. Reject overlapping pulses on same qubit unless explicitly allowed.
- QM-14: add `nuc_lq_release(handle)` for partial release. Return error code on overflow.

**Phase 3 (medium-term):**
- QM-4: track SWAP overhead in MPS routing. Surface to Nucleor and to trace.
- QM-5: add convergence diagnostic to MPS SVD. Warn when 100 iterations don't converge to 1e-28. Document as accuracy boundary.
- QM-10: add Ry/Rz/T/S/CCX/CZ/SWAP CUDA kernels. Implement CPU fallback. Wrap in `gpu_quantum.nr` rod.
- QM-16: add Kraus-operator noise channel. User can specify per-gate noise model independent of learnable diff_sim parameters.
- QM-17: add `qsim_if_measure(cond, then_gate, else_gate)` primitive for fast-feedback semantics.

**Phase 4 (v1.0+, deferred per RFC-0054 Phase B):**
- QM-15: QIR emit and OpenQASM emit/ingest. Major work; gates Phase B target date.

## 3.3. v1.0 release gate
Phase 1 IMMEDIATELY (Clifford zero tests is critical). Phase 2 minimum for v1.0. Phase 3 strongly preferred. Phase 4 explicitly v1.x.

## 3.4. Open questions
1. Should the Clifford test suite include weight enumerator validation against a known code? Recommendation: yes — surface code distance on standard d=3 patch.
2. QM-10 CUDA gate set — extend or replace with cuQuantum integration? Recommendation: extend native (cuQuantum dependency is heavy).
3. QM-16 noise model: which Kraus operators ship by default? Recommendation: depolarizing, dephasing, amplitude damping, phase damping (the four canonical channels).

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
