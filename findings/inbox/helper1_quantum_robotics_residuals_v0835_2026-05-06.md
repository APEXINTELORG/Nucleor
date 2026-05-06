# Helper1 Quantum/Robotics Residual Ledger v0835

Branch: `fix/helper1-quantum-robotics-residuals-v0835`

Base: `origin/fix/main-qm7-surface-code-v0827`

Merge-base: `8413358a276e780cc02322cd089279758a33f593`

## Scope Matrix

| Scope | Current status | Changed files | Validation | Remaining blocker | Owner recommendation |
|---|---|---|---|---|---|
| QM-7 weight enumerator | Closed on integration base. Bounded API and fixture already exist. The fixture locks internal exhaustive Surface-17 stabilizer/logical counts; exact external published enumerator citation remains advisory documentation. | None in this v0835 branch. Existing surface: `stdlib/rods/clifford.nr`, `stdlib/runtime/clifford_rt.c`, `tests/features/qm7_clifford_weight_enumerator_smoke.nr`, `findings/inbox/helper1_qm7_weight_enumerator_v0835_2026-05-06.md`. | `.\bin\nucleor.exe build tests\features\qm7_clifford_weight_enumerator_smoke.nr -o helper1_qm7_weight_enum --no-cache`; `.\target\helper1_qm7_weight_enum.exe`; `bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qm7_clifford_weight_enumerator_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'`. Result: PASS. | Optional external citation/value parity for the published enumerator table. Do not fabricate this from the internal fixture. | Main/helper can treat runtime surface as closed; docs-only follow-up if an external published count table is identified. |
| QM-6 high-qubit MPS streaming/external sink | Closed for first bounded readout. `mps_statevector_range(h, start_basis, count)` exposes caller-capped high-qubit amplitude windows without raising the full-state materialization cap. | `stdlib/runtime/mps_rt.c`; `stdlib/rods/mps.nr`; `tests/features/mps_statevector_range_smoke.nr`; `docs/rfcs/v1_PUNCHLIST.md`; `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`; `findings/inbox/helper1_qm6_mps_statevector_range_v0835_2026-05-06.md`. | `.\bin\nucleor.exe build tests\features\mps_statevector_range_smoke.nr -o helper1_mps_statevector_range_recheck --no-cache`; `.\target\helper1_mps_statevector_range_recheck.exe`; `bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_statevector_range_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'`. Result: PASS. | True external sink/iterator callback API for long scans is still future work if adopters need streaming beyond a bounded Vec window. | Helper/main can add iterator/sink later; current branch is a safe stdlib/runtime cap reduction. |
| qsim graph thread safety | Disclosed and test-backed. Public helpers report the runtime is not thread-safe and requires external serialization. | `stdlib/rods/qsim_graph.nr`; `tests/features/qsim_graph_thread_safety_disclosure_smoke.nr`; `docs/rfcs/v1_PUNCHLIST.md`; `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`; `findings/inbox/helper1_qsim_graph_thread_safety_disclosure_v0835_2026-05-06.md`. | `.\bin\nucleor.exe build tests\features\qsim_graph_thread_safety_disclosure_smoke.nr -o helper1_qsim_graph_thread_recheck --no-cache`; `.\target\helper1_qsim_graph_thread_recheck.exe`; `bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_thread_safety_disclosure_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'`. Result: PASS. | Actual synchronization needs a runtime-owned qsim_graph mutex or per-graph handle state. The current C runtime uses process-local static union-find and gate-DAG arrays. | Main/runtime owner should take the locking or handle-state refactor; helper should not widen this branch into pthread/Windows lock work. |
| QM-12 typed rotations | Closed on integration base; this branch adds a review finding only. Existing policy is correct: shared logical kinds plus backend-specific mappers preserve incompatible native dispatch IDs. | `findings/inbox/helper1_qm12_rotation_id_review_v0835_2026-05-06.md`. Existing surface: `stdlib/rods/quantum_gates.nr`, `stdlib/rods/mps.nr`, `stdlib/rods/diff_sim.nr`, `tests/features/quantum_gate_constants_smoke.nr`. | `.\bin\nucleor.exe build tests\features\quantum_gate_constants_smoke.nr -o helper1_qm12_rotation_ids --no-cache`; `.\target\helper1_qm12_rotation_ids.exe`; `bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_gate_constants_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'`; `git diff --check`. Result: PASS. | Missing rotation families such as RY and controlled rotations are future gate-coverage work, not an ID-unification bug. | Keep the translation-layer policy. Add new rotations by extending logical kinds and per-backend mappers, not by forcing one raw enum. |
| ROBO-14 end-to-end smoke | Closed on integration base. Existing fixture proves IK -> RRT plan -> CHOMP smooth -> TOPP time profile -> FK endpoint on a deterministic planar arm. | None in this v0835 branch. Existing fixture: `tests/features/robo14_end_to_end_smoke.nr`; docs: `docs/rfcs/v1_PUNCHLIST.md`, `docs/rfcs/gap-analyses/Nucleor_Robotics_Control_Stack_Gap_Analysis_and_RFC_2026-05-04.md`. | `.\bin\nucleor.exe build tests\features\robo14_end_to_end_smoke.nr -o helper1_robo14_chain --no-cache`; `.\target\helper1_robo14_chain.exe`; `bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/robo14_end_to_end_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'`. Result: PASS. | Production-grade variant remains: 6-DOF pose/orientation, nonzero collision/obstacle callbacks, and dynamics-aware timing. | Future robotics lane should take the production fixture; this helper branch should not duplicate the existing Phase 1 smoke. |
| ROBO-7 compiler frame enforcement disclosure | Disclosure remains accurate. Frame markers parse and runtime helper checks exist, but compiler-side TYP-008 frame-mismatch enforcement is still not shipped. | None in this v0835 branch. Existing fixture: `tests/features/robotics_typed_pose_chain_smoke.nr`; related rods: `stdlib/rods/kinematics_frame.nr`, `stdlib/rods/kinematics.nr`. | `.\bin\nucleor.exe build tests\features\robotics_typed_pose_chain_smoke.nr -o helper1_robo7_frame_disclosure --no-cache`; `.\target\helper1_robo7_frame_disclosure.exe`; `bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/robotics_typed_pose_chain_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'`. Result: PASS. | Compiler-side type/frame analysis that rejects mismatched frame composition at compile time. | Main owns compiler enforcement. Helper can add docs/fixtures only unless explicitly assigned the compiler pass. |

## Branch Delta

This branch contains two implementation commits plus this residual ledger:

- `248bf62b stdlib: add bounded MPS statevector range readout`
- `aeb07ffa stdlib: disclose qsim graph thread safety boundary`

Files changed relative to base before this ledger:

- `stdlib/runtime/mps_rt.c`
- `stdlib/rods/mps.nr`
- `stdlib/rods/qsim_graph.nr`
- `tests/features/mps_statevector_range_smoke.nr`
- `tests/features/qsim_graph_thread_safety_disclosure_smoke.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `findings/inbox/helper1_qm6_mps_statevector_range_v0835_2026-05-06.md`
- `findings/inbox/helper1_qsim_graph_thread_safety_disclosure_v0835_2026-05-06.md`
- `findings/inbox/helper1_qm12_rotation_id_review_v0835_2026-05-06.md`
- `findings/inbox/helper1_quantum_robotics_residuals_v0835_2026-05-06.md`

## Gate Recommendation

No compiler source, tool gate, promoted binary, or bootstrap seed was edited in
this branch. Main does not need drift/self-host/perf/full verify because of
this branch alone. Recommended integration validation is focused:

```powershell
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_statevector_range_smoke"'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_graph_thread_safety_disclosure_smoke"'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_gate_constants_smoke"'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/robo14_end_to_end_smoke"'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/robotics_typed_pose_chain_smoke"'
git diff --check
```
