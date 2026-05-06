# Helper1 v0831 - QM-6 MPS Joint Probability Closure

Branch: `fix/helper1-qm6-mps-joint-prob-v0831`

Base: `origin/fix/main-qm7-surface-code-v0827`

## Scope

This slice advances the remaining QM-6 MPS probability gap from Bell marginal
readout to computational-basis joint-probability readout.

Changes:

- Added native `nuc_mps_prob_basis(handle, basis_bits)` in
  `stdlib/runtime/mps_rt.c`.
- Added Nucleor rod wrapper `mps_prob_basis(h, basis_bits)` in
  `stdlib/rods/mps.nr`.
- Extended `tests/features/mps_bell_probabilities_smoke.nr` to assert Bell
  joint probabilities:
  - basis `0` / `|00>` -> `0.5`
  - basis `1` / `|01>` -> `0.0`
  - basis `2` / `|10>` -> `0.0`
  - basis `3` / `|11>` -> `0.5`
  - out-of-range basis `4` for a two-qubit MPS -> `0.0`
- Updated the QM-6 docs to mark joint probability shipped and leave only bulk
  statevector extraction open.

## Validation

Direct build/run:

```powershell
.\bin\nucleor.exe build tests\features\mps_bell_probabilities_smoke.nr -o target\_qm6_mps_bell_probs_joint --no-cache
.\target\_qm6_mps_bell_probs_joint.exe
```

Result: PASS.

Focused canonical gates:

```powershell
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_bell_probabilities_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_named_gate_wrappers_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

All four returned `PASS: 1`, `SKIP: 1148`.

Hygiene:

```powershell
git diff --check
```

Result: clean.

## Remaining QM-6 gap

Bulk statevector extraction was still absent after v0831. The v0831 API
provides exact single-basis joint probability without materializing the full
`2^n` vector, which is the right default for MPS memory behavior.

## Follow-on slice - v0832 capped statevector extraction

This branch now also adds a fail-closed bulk extraction API for small MPS
states:

- Added native `nuc_mps_statevector(handle)` and
  `nuc_mps_statevector_max_qubits()` in `stdlib/runtime/mps_rt.c`.
- Added Nucleor wrappers `mps_statevector(h)` and
  `mps_statevector_max_qubits()` in `stdlib/rods/mps.nr`.
- The extraction returns a qsim-compatible `Vec<complex>` so existing
  `vec_get`, `cx_real`, and `cx_imag` accessors work without a second ABI.
- The extraction fails closed above `mps_statevector_max_qubits()` instead of
  materializing unbounded `2^n` state.
- Extended `tests/features/mps_bell_probabilities_smoke.nr` to validate the
  Bell statevector amplitudes and the over-cap fail-closed path.

Remaining QM-6 caveat after v0832: no high-qubit streaming/external-sink
state export. The in-memory statevector API is intentionally capped to avoid
turning MPS into a memory blowup vector.

Validation for v0832:

```powershell
.\bin\nucleor.exe build tests\features\mps_bell_probabilities_smoke.nr -o target\_qm6_mps_bell_statevector --no-cache
.\target\_qm6_mps_bell_statevector.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_bell_probabilities_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_named_gate_wrappers_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Direct build/run passed. All four focused canonical gates returned `PASS: 1`,
`SKIP: 1148`.
