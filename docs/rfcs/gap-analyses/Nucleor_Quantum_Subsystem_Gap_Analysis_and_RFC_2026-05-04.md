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

**Headline finding: Clifford rod coverage is largely closed for deterministic small-code evidence, not complete for ecosystem interop.** 41 KB runtime with stabilizer formalism, distance computation, error detection, and bounded weight-enumerator helpers now has deterministic smoke coverage including a rotated Surface-17 d=3 stabilizer/logical fixture, internal exhaustive stabilizer/logical weight counts, and a bounded property micro-suite. External citation-backed published weight-enumerator parity and QASM/OpenQASM2 interop remain open.

**Second finding: dual entanglement trackers exist and are not wired together.** `quantum_rt.c` has trace-only UF; `qsim_graph_rt.c` has queryable UF. Caller using qsim_graph must manually register entanglements separately from running circuits — easy to forget, no enforcement.

---

# Part II — Gap Inventory

## QM-1 — Header advertises functions that don't exist — **LOW**
`qsim_copy`, `qsim_statevec`, `qsim_prob` advertised in `quantum.nr` header but not implemented in body. Doc/spec drift.

**2026-05-06 update:** QM-1 is closed by making the advertised functions real.
`qsim_prob(sv, q, outcome)` wraps `qsim_prob0` for both measurement outcomes,
`qsim_statevec(sv)` exposes the underlying statevector handle explicitly, and
`qsim_copy(sv)` deep-copies complex amplitude handles so later mutations diverge.
`qsim_header_compat_smoke.nr` locks all three surfaces plus the limitations text.

## QM-2 — Statevector MAX_QUBITS 32 silently miscounts at >32 qubits — **MEDIUM**
Static array in entanglement tracker. Tracker silently stops counting for q >= 32; simulator operates on more qubits — silent miscount in trace events for circuits with 33+ qubits.

**2026-05-06 update:** caller-facing preflight and checked init are now
shipped. `qsim_init_preflight(n)` returns `0=ok`, `1=invalid_qubit_count`, and
`2=over_capacity`; `qsim_init(n)` and `qsim_init_checked(n)` both return `0`
before dangerous invalid/over-cap allocation.
`qsim_state_capacity_status_smoke.nr` covers in-range, invalid, over-cap,
checked-init, and raw-init fail-closed behavior.

## QM-3 — MPS rod exposes only raw integer gate_type enum — **MEDIUM**
No named gate functions (`mps_h`, `mps_x`, `mps_cnot`). Enum values 0–7 documented only in C source comment. Ergonomic gap.

**2026-05-06 update:** Phase 1 named MPS gate wrappers and shared-kind
mapping are now shipped. `mps_h`, `mps_x`, `mps_z`, `mps_rz`, `mps_rx`,
`mps_cnot`, `mps_gate_*` constants, `mps_gate_type_supported`, and
`mps_gate_kind` remove the need for adopter code to use raw magic integers
for shipped MPS gates; `mps_named_gate_wrappers_smoke.nr` and
`quantum_gate_constants_smoke.nr` lock the public surface. Remaining gap:
the raw integer `mps_gate(...)` escape hatch remains for compatibility, and
unsupported gates (Y/S/T/RY/CZ/SWAP/Toffoli/controlled rotations) still need
future runtime dispatch.

## QM-4 — MPS non-adjacent CNOT routing introduces untracked SWAP overhead — **MEDIUM**
SWAP count not reported back to Nucleor or trace. `qtrace_set_original` would double-count SWAP overhead as "transpiler overhead."

## QM-5 — MPS SVD: 100-iter Jacobi with silent clamp on negative eigenvalues — **HIGH**
Correct for small bond dimensions but no documented convergence guarantee beyond 1e-28 off-norm. Near max bond (64), SVD may not converge; singular values silently clamped to zero via `max(eigenvalue, 0)` — **potential silent truncation error with no warning.**

## QM-6 — MPS smoke test is allocation-only — **HIGH**
Original finding: `mps_smoke.nr` tested only `mps_init` + free; no gate was
applied, no statevector/probability was extracted, and no Bell-state test
through MPS existed.

**2026-05-06 update:** MPS correctness coverage is now fixture-backed.
`mps_prob0(h, q)` exposes single-qubit probability readout from the existing
MPS contraction, `mps_prob_basis(h, basis_bits)` exposes full
computational-basis joint probability, `mps_statevector(h)` exposes capped
qsim-compatible `Vec<complex>` extraction, and
`mps_bell_probabilities_smoke.nr` compares Bell-circuit MPS marginals plus
|00>/|11> joint probabilities against the qsim statevector reference
expectations. The bulk extraction path fails closed above
`mps_statevector_max_qubits()` to avoid 2^n memory blowups. Remaining gap: no
high-qubit streaming/external-sink extraction API.

## QM-7 — Clifford rod coverage mostly closed — **MEDIUM REMAINING**
41 KB runtime with stabilizer formalism, distance, error detection, and bounded weight-enumerator helpers. The original zero-test gap is now closed by deterministic Bell/GHZ, gate identity, reset/rebuild, known [[5,1,3]] distance/detectable-error, rotated Surface-17 d=3 stabilizer/logical, Surface-17 stabilizer/logical weight-count, and bounded property micro-suite smokes. Remaining launch risk is validation breadth: external published weight-enumerator value citations are still absent in-tree, QASM/OpenQASM2 interop is absent, and the suite is not a randomized stabilizer property test.

## QM-8 — Two entanglement trackers not wired together — **HIGH**
`quantum_rt.c` (32-qubit, trace-only, no active flag) and `qsim_graph_rt.c` (1024-qubit, queryable, union-by-size). When `qsim_cnot` fires, calls `rods_trace_entangle` (trace UF) but NOT `nuc_qsim_entangle_register` (queryable UF). Caller using `qsim_graph.nr` must manually register entanglements separately — easy to forget, no enforcement.

## QM-9 — Gate-influence DAG silent overflow at 4096 gates — **MEDIUM**
`NUC_QSIM_MAX_GATES 4096`. Larger circuits return -1 from `nuc_qsim_gate_record` but **nothing signals this to Nucleor layer** — silent overflow with partial DAG data.

## QM-10 — CUDA simulator has only H/X/Z/CNOT — **HIGH**
No Ry/Rz/T/S/CCX/CZ/SWAP. Insufficient for VQE/QAOA. CPU fallback documented in comments but not implemented. No Nucleor rod wrapper — GPU path inaccessible from Nucleor circuits without raw extern bindings.

## QM-11 — diff_sim capped at 12 qubits, hard-coded constant — **MEDIUM**
ADAPT-VQE and QEC RL experiments used up to 13 qubits. **13+ qubits cannot use diff_sim.** Compile-time constant in C, not runtime check with clear error.

**2026-05-06 update:** caller-facing preflight and checked init are now
shipped. `diff_sim_init_preflight(nq, n_cores)` exposes stable
invalid/over-cap status codes, and
`diff_sim_init(nq, n_cores, mode_bits, seed)` /
`diff_sim_init_checked(...)` return `0` before the native runtime allocates on
invalid inputs. `diff_sim_capacity_status_smoke.nr` locks the public
12-qubit, 16-core, 200-gate cap surface plus raw-init fail-closed behavior.

## QM-12 — diff_sim and MPS share gate type enum but neither exposes constants — **LOW**
Both start H=0/CNOT=1/X=2 but enum not in shared header or Nucleor constant. Magic integers at callsites. Adding new gate to one without other silently diverges.

**2026-05-06 update:** common shared constants and logical gate kinds are now
shipped. `quantum_gates.nr` exposes H/CNOT/X/Z native IDs, `qgate_kind_*`
logical constants, and explicit `qgate_kind_to_mps` / `qgate_kind_to_diff`
mappers. `quantum_gate_constants_smoke.nr` locks cross-rod consistency and
rotation mapping: RZ routes to MPS native `4` and diff_sim native `6`; RX maps
to MPS native `5` and reports unsupported for diff_sim. Native dispatch tables
remain separate raw ABIs for compatibility, but cross-rod callers no longer
need to reuse raw rotation integers.

## QM-13 — Pulse-level schedule has no qubit-parallel constraint enforcement — **MEDIUM**
`Schedule` doesn't enforce qubit-parallel constraints: two pulses on same qubit at overlapping times can be pushed without error. `schedule_push` places pulses sequentially on global timeline, ignoring qubit_id.

**2026-05-06 update:** Phase 1 validator and Phase 2a checked insertion are
now shipped. `schedule_validate_no_same_qubit_overlap(sched)` detects
same-qubit overlap and malformed schedule rows, while
`schedule_push_at(&mut sched, pulse, qubit, start_ns)` supports
backend-parallel insertion with same-qubit overlap rejection. Fixtures
`logical_qubit_schedule_overlap_preflight_smoke.nr` and
`logical_qubit_schedule_push_at_smoke.nr` cover serialized schedules, parallel
different-qubit insertion, same-qubit overlap rejection, boundary-touching
same-qubit insertion, and invalid rows. Remaining gap: no backend
calibration/resource scheduler or hardware target lowering.

## QM-14 — Logical qubit registry no partial release — **LOW**
Process-global static array `_nuc_lqs[256]`. No free/remove operation, only `nuc_lq_clear` wipes everything. `nuc_lq_register` returns -1 on overflow with no Nucleor-level check in `logical_qubit_new`.

**2026-05-06 update:** registry disclosure/preflight and partial release are
now shipped. `logical_qubit_max_registry`, `logical_qubit_registry_preflight`,
slots-remaining helpers, `logical_qubit_release(lq)`, and
`logical_qubit_release_handle(handle)` are covered by
`logical_qubit_registry_capacity_smoke.nr`. Released slots are reused and
`logical_qubit_clear()` still wipes all entries. Remaining gap: registry state
is process-local and not thread-safe.

## QM-15 — QIR and OpenQASM completely absent — **HIGH** (deferred per RFC-0054 Phase B)
No emit, no ingest, no stub. Users wanting to port from Qiskit/Cirq or run on IBM Q have no path from Nucleor.

## QM-16 — No Kraus-operator or density-matrix noise model — **MEDIUM**
diff_sim noise is learnable parameterized depolarizing but not independently specifiable. Cannot set "apply dephasing channel after each T gate with rate 0.01." Trace-close noise estimate is heuristic, not simulation result.

## QM-17 — Quantum-classical mid-circuit feedback by convention only — **LOW**
`qsim_measure` returns i64; caller branches. No `qsim_if_measure` primitive. This distinction matters for hardware-targeting tools (RFC-0054 Phase B).

## Cross-cutting risks
- **Correctness validation thin.** Only executed correctness test for statevector is Bell entanglement (QM-6). No assertion that |H|0⟩|² = 0.5 within tolerance, no GHZ, no phase-sensitive (T/S/Rz angles). Clifford now has deterministic smoke coverage for Bell/GHZ, gate identity, reset/rebuild, known [[5,1,3]] distance/error-detection behavior, rotated Surface-17 d=3 stabilizer/logical behavior, internal exhaustive Surface-17 stabilizer/logical weight counts, and a bounded property micro-suite, but no broad randomized stabilizer property suite and no in-tree external citation for published enumerator values.
- **Static-capacity constants scattered across four runtimes** (32, 20, 64, 12, 1024, 4096) not centralized, not surfaced to Nucleor as named constants, some overflow silently.
- **Dual-tracker fragmentation risk** (QM-8) — architecturally fine for Phase A but if RFC-0061 Tier 3 Phase B wires them together, both will need active-flag discrepancy review.
- **MPS Jacobi SVD numerical stability** (QM-5) — clamp on negative residuals masks numerical noise as zero bond dimension.

---

# Part III — RFC

## 3.1. Goals
1. Finish the remaining QM-7 validation gap: keep the landed deterministic Clifford smokes, keep the rotated Surface-17 d=3 fixture, bounded weight-enumerator fixture, and bounded property micro-suite, then add external citation-backed published enumerator parity only if launch docs require it.
2. Wire the two entanglement trackers together (QM-8).
3. Keep named gate APIs and centralized capacity constants aligned across rods.
4. Document the Clifford and MPS limits prominently.

## 3.2. Closure plan

**Phase 1 (emergency, test coverage):**
- QM-7: deterministic Clifford suite now covers Bell state via H + CNOT, 3-qubit GHZ, gate identities, reset/rebuild, known [[5,1,3]] distance/detectable-error behavior, rotated Surface-17 d=3 stabilizer/logical behavior, bounded Surface-17 stabilizer/logical weight counts, and bounded property micro-suite behavior. Remaining Phase 2 closure is external published enumerator citation parity and QASM/OpenQASM2 interop. **No Clifford code ships without these tests.**
- QM-6: MPS gate correctness, Bell marginal probabilities,
  computational-basis joint probability, and capped qsim-compatible
  statevector extraction are shipped; remaining work is high-qubit
  streaming/external-sink extraction if needed.
- QM-1: DONE. `qsim_prob`, `qsim_statevec`, and `qsim_copy` now exist and
  are fixture-backed.
- QM-2: preflight/disclosure, `qsim_init_checked`, and raw `qsim_init`
  fail-closed behavior are shipped.

**Phase 2 (short-term):**
- QM-3: named MPS wrappers, supported-code queries, and logical gate-kind
  mapping are shipped. Remaining work is adding missing MPS runtime gates and
  eventually retiring or fencing the raw integer escape hatch.
- QM-8: wire `qsim_cnot` to call BOTH `rods_trace_entangle` AND `nuc_qsim_entangle_register`. Single source of truth for entanglement state.
- QM-9: emit runtime panic when gate DAG exceeds 4096 gates instead of silent -1.
- QM-11: preflight/disclosure and `diff_sim_init_checked` are shipped;
  remaining work is native no-clamp error behavior if raw `diff_sim_init`
  remains public, or a configurable cap.
- QM-12: shared H/CNOT/X/Z constants and logical gate-kind mappers are shipped
  and consumed by diff_sim and MPS; native dispatch tables remain separate raw
  ABIs for compatibility.
- QM-13: schedule overlap validator and `schedule_push_at` checked insertion
  are shipped; remaining work is backend calibration/resource scheduling and
  hardware target lowering.
- QM-14: registry cap preflight and partial release are shipped; remaining
  work is thread-safety / backend ownership semantics.

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
