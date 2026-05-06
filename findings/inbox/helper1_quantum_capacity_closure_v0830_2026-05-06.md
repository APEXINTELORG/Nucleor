# Helper1 quantum capacity closure v0830

Branch: `fix/helper1-r11-quantum-capacity-closure-v0830`

Base: `origin/main` at `5ec86d7e4d965359348d33826553659157d16016`

## Completed scopes

### Scope P - QM-2 statevector capacity/status closure

Implemented stdlib-only preflight helpers in `stdlib/rods/quantum.nr`:

- `qsim_status_ok()`
- `qsim_status_invalid_qubit_count()`
- `qsim_status_over_capacity()`
- `qsim_init_preflight(n)`
- `qsim_status_explain(status)`

Added fixture:

- `tests/features/qsim_state_capacity_status_smoke.nr`

This locks in-range, invalid, and over-cap behavior without invoking a dangerous
over-cap `qsim_init`.

Remaining blocker: raw `qsim_init(n)` still relies on caller discipline. A
future native/runtime fail-closed check should reject over-cap initialization
if callers bypass the preflight helper.

### Scope Q - QM-11 diff_sim capacity/status closure

Implemented stdlib-only cap/status helpers in `stdlib/rods/diff_sim.nr`:

- `diff_sim_max_qubits() == 12`
- `diff_sim_max_cores() == 16`
- `diff_sim_min_cores() == 2`
- `diff_sim_max_gates() == 200`
- `diff_sim_init_preflight(nq, n_cores)`
- `diff_sim_status_explain(status)`

Also added diff_sim named gate constants:

- `diff_gate_h()`
- `diff_gate_cnot()`
- `diff_gate_x()`
- `diff_gate_z()`
- `diff_gate_rz()`
- `diff_gate_type_supported(gate_type)`

Added fixture:

- `tests/features/diff_sim_capacity_status_smoke.nr`

Remaining blocker: native `nuc_diff_sim_init` still clamps over-cap qubits and
core counts instead of returning a clear failure status. Full QM-11 closure
requires a runtime/stdlib ABI that does not silently clamp.

### Scope R - QM-13 pulse-level schedule overlap preflight

Implemented stdlib-only validator helpers in `stdlib/rods/logical_qubit.nr`:

- `schedule_status_ok()`
- `schedule_status_overlap()`
- `schedule_status_invalid()`
- `schedule_validate_no_same_qubit_overlap(sched)`

Added fixture:

- `tests/features/logical_qubit_schedule_overlap_preflight_smoke.nr`

The fixture covers serialized same-qubit schedules, parallel different-qubit
schedules, overlapping same-qubit schedules, and invalid zero-duration rows.

Remaining blocker: `schedule_push` still serializes globally and does not model
backend parallel scheduling. A future `schedule_push_at` or backend-aware
scheduler is needed for full QM-13 closure.

### Scope S - QM-14 logical-qubit registry disclosure

Implemented stdlib-only registry cap helpers in `stdlib/rods/logical_qubit.nr`:

- `logical_qubit_max_registry() == 256`
- `logical_qubit_registry_slots_remaining()`
- `logical_qubit_can_allocate()`
- `logical_qubit_registry_preflight()`

Added fixture:

- `tests/features/logical_qubit_registry_capacity_smoke.nr`

The fixture fills the 256-entry registry, verifies overflow handle `-1`, and
verifies the count does not increase after overflow.

Remaining blocker: no partial release API exists. Full QM-14 closure requires
`nuc_lq_release(handle)` or equivalent.

### Scope T - remaining-blocker compression

Updated:

- `docs/rfcs/v1_PUNCHLIST.md`
- `docs/rfcs/gap-analyses/Nucleor_Quantum_Subsystem_Gap_Analysis_and_RFC_2026-05-04.md`
- `docs/rfcs/gap-analyses/README.md`

## Validation

Direct builds/runs:

```powershell
.\bin\nucleor.exe build tests\features\qsim_state_capacity_status_smoke.nr -o target\_qm2_statevector_capacity --no-cache
.\target\_qm2_statevector_capacity.exe
.\bin\nucleor.exe build tests\features\diff_sim_capacity_status_smoke.nr -o target\_qm11_diff_sim_capacity --no-cache
.\target\_qm11_diff_sim_capacity.exe
.\bin\nucleor.exe build tests\features\logical_qubit_schedule_overlap_preflight_smoke.nr -o target\_qm13_pulse_schedule --no-cache
.\target\_qm13_pulse_schedule.exe
.\bin\nucleor.exe build tests\features\logical_qubit_registry_capacity_smoke.nr -o target\_qm14_logical_registry --no-cache
.\target\_qm14_logical_registry.exe
```

All direct builds/runs passed.

Focused canonical gate checks:

```powershell
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_state_capacity_status_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_capacity_status_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_schedule_overlap_preflight_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_registry_capacity_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

All four returned `PASS: 1`, `SKIP: 1127`.

Nearby regression checks:

```powershell
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_state_disclosure_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_f64" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_limitations_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

All five returned `PASS: 1`, `SKIP: 1127`.

Assignment audit sweeps completed:

```powershell
rg -n "diff_sim|DIFF|capacity|cap|status|qubit" stdlib tests docs
rg -n "pulse|schedule|overlap|duration|quantum" stdlib tests docs
rg -n "logical|registry|qubit|capacity|status" stdlib tests docs
rg -n "QM-2|QM-3|QM-6|QM-11|QM-12|QM-13|QM-14" docs stdlib tests
```

## Follow-on slice - QM-13 checked schedule insertion

After the first push, this branch also advanced the QM-13 remaining blocker with
a stdlib-only checked insertion surface:

- `schedule_push_at(&mut sched, pulse, qubit_id, start_ns)`
- `schedule_total_duration(sched)` now reports the maximum scheduled end time
  instead of relying on the last row, so explicitly parallel schedules have the
  correct makespan.
- `schedule_push(sched, pulse, qubit_id)` remains the legacy serialized append.

Added fixture:

- `tests/features/logical_qubit_schedule_push_at_smoke.nr`

The fixture covers backend-parallel different-qubit insertion, same-qubit
overlap rejection without mutation, boundary-touching same-qubit insertion,
invalid rows, and limitations-string disclosure.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\logical_qubit_schedule_push_at_smoke.nr -o target\_qm13_schedule_push_at --no-cache
.\target\_qm13_schedule_push_at.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_schedule_push_at_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_schedule_overlap_preflight_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_registry_capacity_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Direct build/run passed. All four focused canonical gate checks returned
`PASS: 1`, `SKIP: 1128`.

## Follow-on slice - QM-12 shared gate constants

This branch also closes the QM-12 common-constant gap without changing any
native runtime ABI:

- Added `stdlib/rods/quantum_gates.nr`.
- Migrated `mps.nr` and `diff_sim.nr` to consume shared H/CNOT/X/Z constants.
- Kept rotation constants explicitly rod-specific because native dispatch
  tables diverge today: MPS `RZ=4/RX=5`, diff_sim `RZ=6`.

Added fixture:

- `tests/features/quantum_gate_constants_smoke.nr`

Validation:

```powershell
.\bin\nucleor.exe build tests\features\quantum_gate_constants_smoke.nr -o target\_qm12_quantum_gate_constants --no-cache
.\target\_qm12_quantum_gate_constants.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_gate_constants_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_named_gate_wrappers_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_capacity_status_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Direct build/run passed. All five focused canonical gate checks returned
`PASS: 1`, `SKIP: 1129`.

## Follow-on slice - QM-2/QM-11 checked init wrappers

This branch also adds stdlib-only fail-closed initialization wrappers without
changing native runtime ABI:

- `qsim_init_checked(n)` returns `0` for invalid or over-cap counts before
  allocating the statevector.
- `diff_sim_init_checked(nq, n_cores, mode_bits, seed)` returns `0` before the
  native diff_sim runtime can clamp invalid qubit/core counts.

Updated fixtures:

- `tests/features/qsim_state_capacity_status_smoke.nr`
- `tests/features/diff_sim_capacity_status_smoke.nr`

Validation:

```powershell
.\bin\nucleor.exe build tests\features\qsim_state_capacity_status_smoke.nr -o target\_qm2_statevector_capacity --no-cache
.\target\_qm2_statevector_capacity.exe
.\bin\nucleor.exe build tests\features\diff_sim_capacity_status_smoke.nr -o target\_qm11_diff_sim_capacity --no-cache
.\target\_qm11_diff_sim_capacity.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/qsim_state_capacity_status_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/diff_sim_capacity_status_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Both direct build/run checks passed. Both focused canonical gate checks returned
`PASS: 1`, `SKIP: 1129`.

## Follow-on slice - QM-14 partial logical-qubit release

This branch also closes the partial-release gap with a tiny runtime ABI addition:

- Added `nuc_lq_release(handle)` in `stdlib/runtime/logical_qubit_rt.c`.
- Changed logical-qubit registry allocation from high-water-only to first-free
  slot reuse.
- Made `nuc_lq_count()` return active entries, and made code/distance lookup
  return `0` for released handles.
- Added `logical_qubit_release(lq)` and
  `logical_qubit_release_handle(handle)` wrappers.

Updated fixture:

- `tests/features/logical_qubit_registry_capacity_smoke.nr`

Validation:

```powershell
.\bin\nucleor.exe build tests\features\logical_qubit_registry_capacity_smoke.nr -o target\_qm14_logical_registry --no-cache
.\target\_qm14_logical_registry.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_registry_capacity_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_schedule_push_at_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Direct build/run passed. All three focused canonical gate checks returned
`PASS: 1`, `SKIP: 1129`.

## Follow-on slice - QM-6 MPS Bell probability readout

This branch also closes the MPS Bell marginal-probability gap with a small
runtime readout API:

- Added `nuc_mps_prob0(handle, q)` in `stdlib/runtime/mps_rt.c`.
- Added `mps_prob0(h, q)` in `stdlib/rods/mps.nr`.
- Added `tests/features/mps_bell_probabilities_smoke.nr`, comparing MPS
  Bell-circuit marginals against the qsim reference.

Validation:

```powershell
.\bin\nucleor.exe build tests\features\mps_bell_probabilities_smoke.nr -o target\_qm6_mps_bell_probs --no-cache
.\target\_qm6_mps_bell_probs.exe
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_bell_probabilities_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/mps_named_gate_wrappers_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
bash -lc 'tools/verify.sh --sequential-fixtures --only "test features/quantum_smoke" | tail -n 12; exit ${PIPESTATUS[0]}'
```

Direct build/run passed. All four focused canonical gate checks returned
`PASS: 1`, `SKIP: 1130`.

## Remaining blocker matrix

| Blocker | Current status | Exact surface needed | Owner suggestion | Focused validation after implementation |
| --- | --- | --- | --- | --- |
| QM-2 native qsim init fail-closed | `qsim_init_preflight` and `qsim_init_checked` shipped; raw `qsim_init` remains public | Native fail-closed behavior if the raw escape hatch stays public | main/helper depending on runtime-edit allowance | `bash tools/verify.sh --sequential-fixtures --only "test features/qsim_state_capacity_status_smoke"` plus raw-overcap policy fixture if native behavior changes |
| QM-11 native diff_sim no-clamp status | `diff_sim_init_preflight` and `diff_sim_init_checked` shipped; raw native init still clamps when called directly | Native no-clamp error behavior if the raw escape hatch stays public | main if ABI change; helper if wrapper-only | `bash tools/verify.sh --sequential-fixtures --only "test features/diff_sim_capacity_status_smoke"` plus raw native no-clamp fixture if ABI changes |
| QM-12 shared gate constants | common H/CNOT/X/Z shared rod shipped and consumed by MPS + diff_sim; rotations remain rod-specific | Typed/cross-rod rotation enum after native dispatch tables unify | main/helper depending on native dispatch scope | `bash tools/verify.sh --sequential-fixtures --only "test features/quantum_gate_constants_smoke"` plus rotation enum fixture |
| QM-13 backend-aware schedule insertion | `schedule_validate_no_same_qubit_overlap` and `schedule_push_at` shipped; legacy `schedule_push` remains serialized append | Backend calibration/resource scheduler and hardware target lowering | main/helper depending on backend scope | `bash tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_schedule_push_at_smoke"` plus backend-specific scheduler fixture |
| QM-14 partial logical-qubit release | `nuc_lq_release`, Nucleor wrappers, active count, and slot reuse shipped | Thread-safety / backend ownership semantics if registry becomes concurrent | main/helper depending on runtime scope | `bash tools/verify.sh --sequential-fixtures --only "test features/logical_qubit_registry_capacity_smoke"` plus concurrent registry fixture when threading semantics exist |
| QM-6 MPS Bell probabilities | `mps_prob0` and Bell marginal fixture shipped; no joint probability/statevector extraction | Full joint-probability or statevector extraction API | main/helper depending on runtime ABI | `bash tools/verify.sh --sequential-fixtures --only "test features/mps_bell_probabilities_smoke"` plus joint-probability fixture |
